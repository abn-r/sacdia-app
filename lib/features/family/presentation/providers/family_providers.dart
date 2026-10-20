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
import '../../domain/entities/dependent_progress_summary.dart';
import '../../domain/entities/supervised_login.dart';
import '../../domain/repositories/family_repository.dart';
import '../../domain/usecases/create_dependent.dart';
import '../../domain/usecases/get_consent_evidence.dart';
import '../../domain/usecases/get_deletion_impact.dart';
import '../../domain/usecases/enable_supervised_login.dart';
import '../../domain/usecases/get_dependent_detail.dart';
import '../../domain/usecases/get_progress_summary.dart';
import '../../domain/usecases/get_supervised_login.dart';
import '../../domain/usecases/manage_supervised_login.dart';
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
final uploadActingConsentEvidenceUseCaseProvider =
    Provider<UploadActingConsentEvidence>(
  (ref) => UploadActingConsentEvidence(ref.read(familyRepositoryProvider)),
);
final getGuardianConsentEvidenceUseCaseProvider =
    Provider<GetGuardianConsentEvidence>(
  (ref) => GetGuardianConsentEvidence(ref.read(familyRepositoryProvider)),
);

final getSupervisedLoginUseCaseProvider = Provider<GetSupervisedLogin>(
  (ref) => GetSupervisedLogin(ref.read(familyRepositoryProvider)),
);
final enableSupervisedLoginUseCaseProvider = Provider<EnableSupervisedLogin>(
  (ref) => EnableSupervisedLogin(ref.read(familyRepositoryProvider)),
);
final disableSupervisedLoginUseCaseProvider = Provider<DisableSupervisedLogin>(
  (ref) => DisableSupervisedLogin(ref.read(familyRepositoryProvider)),
);
final reactivateSupervisedLoginUseCaseProvider =
    Provider<ReactivateSupervisedLogin>(
  (ref) => ReactivateSupervisedLogin(ref.read(familyRepositoryProvider)),
);
final resetSupervisedPasswordUseCaseProvider =
    Provider<ResetSupervisedPassword>(
  (ref) => ResetSupervisedPassword(ref.read(familyRepositoryProvider)),
);
final getProgressSummaryUseCaseProvider = Provider<GetProgressSummary>(
  (ref) => GetProgressSummary(ref.read(familyRepositoryProvider)),
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

/// Elegibilidad y estado del acceso propio de un menor (FP3-11, FP3-13).
final supervisedLoginProvider =
    FutureProvider.autoDispose.family<SupervisedLoginStatus, String>((
  ref,
  dependentId,
) async {
  final result = await ref.read(getSupervisedLoginUseCaseProvider)(dependentId);
  return result.fold((failure) => throw failure, (status) => status);
});

/// Resumen de progreso y asistencia del menor (FP3-26). Sin datos de salud.
final dependentProgressSummaryProvider = FutureProvider.autoDispose
    .family<DependentProgressSummary, String>((ref, dependentId) async {
  final result = await ref.read(getProgressSummaryUseCaseProvider)(dependentId);
  return result.fold((failure) => throw failure, (summary) => summary);
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

  /// Sube la ficha ACTUANDO por el menor (paso 3 del post-registro).
  ///
  /// A diferencia de [uploadConsentEvidence] esta llamada SÍ lleva
  /// `X-Acting-For`: el servidor resuelve la tutoría desde el principal. Si el
  /// director verificó mientras tanto (409 ya verificada) se vuelve a pedir
  /// `/auth/me` para que el estado de consentimiento se actualice.
  Future<Either<Failure, ConsentEvidenceReceipt>>
      uploadConsentEvidenceWhileActing(
    String dependentUserId,
    ConsentEvidenceLocalFile file,
  ) async {
    final result = await _ref.read(uploadActingConsentEvidenceUseCaseProvider)(
      UploadActingConsentEvidenceParams(
        dependentUserId: dependentUserId,
        file: file,
      ),
    );
    if (result.fold(isConsentAlreadyVerified, (_) => false)) {
      unawaited(
        _ref
            .read(authNotifierProvider.notifier)
            .refreshCurrentUser(keepCurrentOnFailure: true),
      );
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

  /// Activa el acceso propio del menor. Tras activarlo, el tutor deja de poder
  /// actuar por él: la lista, el detalle y el estado se vuelven a leer.
  Future<Either<Failure, EnabledSupervisedLogin>> enableSupervisedLogin(
    EnableSupervisedLoginParams params,
  ) async {
    final result =
        await _ref.read(enableSupervisedLoginUseCaseProvider)(params);
    if (result.isRight()) _refreshAccess(params.dependentId);
    return result;
  }

  Future<Either<Failure, SupervisedLoginInfo>> disableSupervisedLogin(
    DisableSupervisedLoginParams params,
  ) async {
    final result =
        await _ref.read(disableSupervisedLoginUseCaseProvider)(params);
    if (result.isRight()) _refreshAccess(params.dependentId);
    return result;
  }

  Future<Either<Failure, SupervisedLoginInfo>> reactivateSupervisedLogin(
    ReactivateSupervisedLoginParams params,
  ) async {
    final result =
        await _ref.read(reactivateSupervisedLoginUseCaseProvider)(params);
    if (result.isRight()) _refreshAccess(params.dependentId);
    return result;
  }

  Future<Either<Failure, PasswordResetResult>> resetSupervisedPassword(
    ResetSupervisedPasswordParams params,
  ) async {
    final result =
        await _ref.read(resetSupervisedPasswordUseCaseProvider)(params);
    if (result.isRight()) _refreshAccess(params.dependentId);
    return result;
  }

  void _refreshAccess(String dependentId) {
    _ref.invalidate(supervisedLoginProvider(dependentId));
    _ref.invalidate(dependentDetailProvider(dependentId));
    _ref.invalidate(dependentsProvider);
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
