import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/consent/consent_error_messages.dart';
import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../post_registration/data/models/relationship_type_model.dart';
import '../../data/datasources/family_remote_data_source.dart';
import '../../data/repositories/family_repository_impl.dart';
import '../../domain/entities/dependent.dart';
import '../../domain/repositories/family_repository.dart';
import '../../domain/usecases/create_dependent.dart';
import '../../domain/usecases/get_consent_evidence.dart';
import '../../domain/usecases/get_deletion_impact.dart';
import '../../domain/usecases/get_dependent_detail.dart';
import '../../domain/usecases/issue_link_code.dart';
import '../../domain/usecases/list_dependents.dart';
import '../../domain/usecases/redeem_link_code.dart';
import '../../domain/usecases/revoke_guardianship.dart';
import '../../domain/usecases/upload_consent_evidence.dart';

// ── Infraestructura ──────────────────────────────────────────────────────────

final familyRemoteDataSourceProvider = Provider<FamilyRemoteDataSource>((ref) {
  return FamilyRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepositoryImpl(
    remoteDataSource: ref.read(familyRemoteDataSourceProvider),
  );
});

final listDependentsUseCaseProvider = Provider<ListDependents>(
  (ref) => ListDependents(ref.read(familyRepositoryProvider)),
);
final getDependentDetailUseCaseProvider = Provider<GetDependentDetail>(
  (ref) => GetDependentDetail(ref.read(familyRepositoryProvider)),
);
final createDependentUseCaseProvider = Provider<CreateDependent>(
  (ref) => CreateDependent(ref.read(familyRepositoryProvider)),
);
final issueLinkCodeUseCaseProvider = Provider<IssueLinkCode>(
  (ref) => IssueLinkCode(ref.read(familyRepositoryProvider)),
);
final redeemLinkCodeUseCaseProvider = Provider<RedeemLinkCode>(
  (ref) => RedeemLinkCode(ref.read(familyRepositoryProvider)),
);
final revokeGuardianshipUseCaseProvider = Provider<RevokeGuardianship>(
  (ref) => RevokeGuardianship(ref.read(familyRepositoryProvider)),
);
final getDeletionImpactUseCaseProvider = Provider<GetDeletionImpact>(
  (ref) => GetDeletionImpact(ref.read(familyRepositoryProvider)),
);
final uploadGuardianConsentEvidenceUseCaseProvider =
    Provider<UploadGuardianConsentEvidence>(
  (ref) => UploadGuardianConsentEvidence(ref.read(familyRepositoryProvider)),
);
final getGuardianConsentEvidenceUseCaseProvider =
    Provider<GetGuardianConsentEvidence>(
  (ref) => GetGuardianConsentEvidence(ref.read(familyRepositoryProvider)),
);

// ── Datos ────────────────────────────────────────────────────────────────────
//
// Ninguno es `keepAlive`: son del tutor y se sueltan al salir de la pantalla,
// así que no pueden sobrevivir a un cambio de perfil.

/// Menores del tutor con el límite. Falla con el [Failure] original.
final dependentsProvider = FutureProvider.autoDispose<FamilyOverview>((
  ref,
) async {
  final result = await ref.read(listDependentsUseCaseProvider)(
    const NoParams(),
  );
  return result.fold((failure) => throw failure, (overview) => overview);
});

/// Parentescos que el tutor puede elegir con un menor (`GET
/// /guardianships/relationship-types`): Padre, Madre, Tutor Legal, Abuelo(a),
/// Tío(a), Hermano/a Mayor, Otro. Es distinto de `relationshipTypesProvider`
/// (catálogo completo, solo para contactos de emergencia). No se filtra por
/// UUID: cambian por ambiente, la lista la fija el servidor.
final guardianshipRelationshipTypesProvider =
    FutureProvider.autoDispose<List<RelationshipTypeModel>>((ref) {
  return ref.read(familyRemoteDataSourceProvider).getRelationshipTypes();
});

/// Detalle de un menor (tutores y consentimiento).
final dependentDetailProvider =
    FutureProvider.autoDispose.family<DependentDetail, String>((
  ref,
  dependentId,
) async {
  final result = await ref.read(getDependentDetailUseCaseProvider)(
    dependentId,
  );
  return result.fold((failure) => throw failure, (detail) => detail);
});

/// Qué pasaría con cada menor si el tutor borra su cuenta.
final deletionImpactProvider =
    FutureProvider.autoDispose<List<DeletionImpactEntry>>((ref) async {
  final result = await ref.read(getDeletionImpactUseCaseProvider)(
    const NoParams(),
  );
  return result.fold((failure) => throw failure, (entries) => entries);
});

// ── Acciones ─────────────────────────────────────────────────────────────────

/// Acciones de Mi familia. Tras una mutación exitosa refresca la lista y los
/// contadores de `/auth/me` (`family.dependents_count`).
class FamilyActions {
  FamilyActions(this._ref);

  final Ref _ref;

  Future<Either<Failure, DependentSummary>> createDependent(
    CreateDependentInput input,
  ) async {
    final result = await _ref.read(createDependentUseCaseProvider)(input);
    // No se refresca `/auth/me` aquí: el llamador cambia enseguida al perfil
    // del menor y al volver al tutor se recarga con el contador nuevo.
    if (result.isRight()) _ref.invalidate(dependentsProvider);
    return result;
  }

  Future<Either<Failure, IssuedLinkCode>> issueLinkCode(String dependentId) {
    return _ref.read(issueLinkCodeUseCaseProvider)(dependentId);
  }

  Future<Either<Failure, DependentSummary>> redeemLinkCode(
    RedeemLinkCodeParams params,
  ) async {
    final result = await _ref.read(redeemLinkCodeUseCaseProvider)(params);
    if (result.isRight()) _refreshFamily();
    return result;
  }

  Future<Either<Failure, RevokeResult>> revoke(
    RevokeGuardianshipParams params,
  ) async {
    final result = await _ref.read(revokeGuardianshipUseCaseProvider)(params);
    if (result.isRight()) _refreshFamily();
    return result;
  }

  /// Sube la ficha firmada del menor. Tras subirla refresca el detalle y la
  /// lista (`evidence_uploaded`); el consentimiento sigue `pending` hasta que un
  /// director lo verifique.
  Future<Either<Failure, ConsentEvidenceReceipt>> uploadConsentEvidence(
    String dependentId,
    ConsentEvidenceLocalFile file,
  ) async {
    final result =
        await _ref.read(uploadGuardianConsentEvidenceUseCaseProvider)(
      UploadGuardianConsentEvidenceParams(dependentId: dependentId, file: file),
    );
    // Si el director verificó mientras tanto (409 ya verificada) el detalle y la
    // lista están desactualizados: también se refrescan.
    final stale = result.fold(isConsentAlreadyVerified, (_) => true);
    if (stale) {
      _ref.invalidate(dependentDetailProvider(dependentId));
      _ref.invalidate(dependentsProvider);
    }
    return result;
  }

  /// Ficha vigente con URL firmada. La URL caduca: se pide cada vez que se va a
  /// mostrar y no se guarda.
  Future<Either<Failure, ConsentEvidenceAccess>> getConsentEvidence(
    String dependentId,
  ) {
    return _ref.read(getGuardianConsentEvidenceUseCaseProvider)(dependentId);
  }

  void _refreshFamily() {
    _ref.invalidate(dependentsProvider);
    _ref.invalidate(deletionImpactProvider);
    unawaited(
      _ref
          .read(authNotifierProvider.notifier)
          .refreshCurrentUser(keepCurrentOnFailure: true),
    );
  }
}

final familyActionsProvider = Provider<FamilyActions>(FamilyActions.new);
