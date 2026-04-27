import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/active_sessions_remote_data_source.dart';
import '../../data/repositories/active_sessions_repository_impl.dart';
import '../../domain/entities/active_session.dart';
import '../../domain/repositories/active_sessions_repository.dart';

// ── Infrastructure providers ───────────────────────────────────────────────────

final activeSessionsDataSourceProvider =
    Provider<ActiveSessionsRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return ActiveSessionsRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

final activeSessionsRepositoryProvider =
    Provider<ActiveSessionsRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final remoteDataSource = ref.read(activeSessionsDataSourceProvider);

  return ActiveSessionsRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

// ── Notifier ───────────────────────────────────────────────────────────────────

/// Notifier de sesiones activas.
///
/// - [build] carga la lista desde el servidor (sin caché, siempre fresco).
/// - [refresh] fuerza recarga manual.
/// - [revoke] aplica optimistic remove + rollback si falla.
/// - [revokeAllOthers] elimina todas las sesiones excepto la actual.
class ActiveSessionsNotifier
    extends AutoDisposeAsyncNotifier<List<ActiveSession>> {
  static const _tag = 'ActiveSessionsNotifier';

  @override
  Future<List<ActiveSession>> build() async {
    final userId = await ref.watch(
      authNotifierProvider.selectAsync((user) => user?.id),
    );
    if (userId == null) return [];

    final result =
        await ref.read(activeSessionsRepositoryProvider).list();

    return result.fold(
      (failure) {
        AppLogger.w(
          'Error al cargar sesiones activas: ${failure.message}',
          tag: _tag,
        );
        // Propagar el error para que la UI muestre el estado de error + retry.
        throw failure;
      },
      (sessions) => sessions,
    );
  }

  /// Fuerza recarga desde el servidor.
  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  /// Revoca una sesión por ID con optimistic remove.
  ///
  /// Retorna null en éxito o un mensaje de error localizado.
  Future<String?> revoke(String sessionId) async {
    final previous = state.valueOrNull;
    if (previous == null) return 'profile.active_sessions.errors.no_sessions_loaded'.tr();

    // Optimistic remove — quitar de la lista localmente de inmediato.
    state = AsyncData(
      previous.where((s) => s.sessionId != sessionId).toList(),
    );

    final result =
        await ref.read(activeSessionsRepositoryProvider).revoke(sessionId);

    return result.fold(
      (failure) {
        // Rollback al estado anterior si el backend falla.
        state = AsyncData(previous);
        AppLogger.w(
          'Rollback de revoke $sessionId tras error: ${failure.message}',
          tag: _tag,
        );
        return failure.message;
      },
      (_) {
        AppLogger.i('Sesión $sessionId revocada', tag: _tag);
        return null;
      },
    );
  }

  /// Revoca todas las sesiones excepto la actual.
  ///
  /// Retorna el número de sesiones revocadas, o un mensaje de error.
  Future<({int count, String? error})> revokeAllOthers() async {
    final previous = state.valueOrNull;
    if (previous == null) return (count: 0, error: 'profile.active_sessions.errors.no_sessions_loaded'.tr());

    final othersCount = previous.where((s) => !s.isCurrent).length;

    // Optimistic remove — dejar solo la sesión actual.
    state = AsyncData(previous.where((s) => s.isCurrent).toList());

    final result =
        await ref.read(activeSessionsRepositoryProvider).revokeAllOthers();

    return result.fold(
      (failure) {
        // Rollback.
        state = AsyncData(previous);
        AppLogger.w(
          'Rollback de revokeAll tras error: ${failure.message}',
          tag: _tag,
        );
        return (count: 0, error: failure.message);
      },
      (count) {
        AppLogger.i('$count sesiones revocadas', tag: _tag);
        // El count del servidor puede diferir del estimado local — preferir el del server.
        return (count: count > 0 ? count : othersCount, error: null);
      },
    );
  }
}

/// Provider singleton de sesiones activas.
///
/// autoDispose: se destruye al salir de la pantalla y fuerza GET fresco
/// la próxima vez que el usuario abre la pantalla.
final activeSessionsProvider = AsyncNotifierProvider.autoDispose<
    ActiveSessionsNotifier, List<ActiveSession>>(
  ActiveSessionsNotifier.new,
);
