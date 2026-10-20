import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/teen_remote_data_source.dart';
import '../../data/repositories/teen_repository_impl.dart';
import '../../domain/entities/teen_supervision.dart';
import '../../domain/repositories/teen_repository.dart';
import '../../domain/usecases/get_supervision.dart';
import '../../domain/usecases/issue_teen_link_code.dart';
import '../../domain/usecases/revoke_pending_guardian_link.dart';

// ── Infraestructura ──────────────────────────────────────────────────────────

final teenRemoteDataSourceProvider = Provider<TeenRemoteDataSource>((ref) {
  return TeenRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final teenRepositoryProvider = Provider<TeenRepository>((ref) {
  return TeenRepositoryImpl(
    remoteDataSource: ref.read(teenRemoteDataSourceProvider),
  );
});

final getSupervisionUseCaseProvider = Provider<GetSupervision>(
  (ref) => GetSupervision(ref.read(teenRepositoryProvider)),
);
final issueTeenLinkCodeUseCaseProvider = Provider<IssueTeenLinkCode>(
  (ref) => IssueTeenLinkCode(ref.read(teenRepositoryProvider)),
);
final revokePendingGuardianLinkUseCaseProvider =
    Provider<RevokePendingGuardianLink>(
  (ref) => RevokePendingGuardianLink(ref.read(teenRepositoryProvider)),
);

// ── Datos ────────────────────────────────────────────────────────────────────
//
// Ambos son estado del adolescente (el código en claro solo vive aquí, en
// memoria): están en el registro de perfil y se purgan al cerrar sesión y al
// cambiar de perfil.

/// `GET /users/me/supervision`: tutores vinculados, reloj y código abierto.
/// Falla con el [Failure] original.
final supervisionStatusProvider = FutureProvider<TeenSupervision>((ref) async {
  final result = await ref.read(getSupervisionUseCaseProvider)(
    const NoParams(),
  );
  return result.fold((failure) => throw failure, (supervision) => supervision);
});

/// Código recién generado para el tutor. `null` mientras no se haya generado
/// uno en esta sesión de pantalla: el servidor solo entrega el texto al
/// crearlo, así que tras salir de la pantalla hay que generar otro (el
/// anterior deja de servir).
class TeenLinkCodeNotifier extends AsyncNotifier<TeenLinkCode?> {
  @override
  Future<TeenLinkCode?> build() async => null;

  /// Genera un código nuevo. Devuelve `true` si lo consiguió; si no, el error
  /// queda en el estado.
  Future<bool> issue() async {
    if (state.isLoading) return false;
    state = const AsyncLoading<TeenLinkCode?>().copyWithPrevious(state);
    final Either<Failure, TeenLinkCode> result =
        await ref.read(issueTeenLinkCodeUseCaseProvider)(const NoParams());
    return result.fold(
      (failure) {
        state = AsyncError<TeenLinkCode?>(failure, StackTrace.current);
        return false;
      },
      (code) {
        state = AsyncData<TeenLinkCode?>(code);
        // El código abierto (vencimiento) cambió en el servidor.
        ref.invalidate(supervisionStatusProvider);
        return true;
      },
    );
  }
}

final teenLinkCodeProvider =
    AsyncNotifierProvider<TeenLinkCodeNotifier, TeenLinkCode?>(
  TeenLinkCodeNotifier.new,
);

// ── Acciones ─────────────────────────────────────────────────────────────────

class TeenActions {
  TeenActions(this._ref);

  final Ref _ref;

  /// Quita un vínculo pendiente que el adolescente inició. Tras quitarlo se
  /// vuelve a leer la supervisión y `/auth/me` (el reloj de 90 días se reinicia
  /// en el servidor).
  Future<Either<Failure, void>> revokePendingLink(
    String guardianshipId,
  ) async {
    final result = await _ref
        .read(revokePendingGuardianLinkUseCaseProvider)(guardianshipId);
    if (result.isRight()) {
      _ref.invalidate(supervisionStatusProvider);
      unawaited(
        _ref.read(authNotifierProvider.notifier).refreshSupervision(),
      );
    }
    return result;
  }
}

final teenActionsProvider = Provider<TeenActions>(TeenActions.new);
