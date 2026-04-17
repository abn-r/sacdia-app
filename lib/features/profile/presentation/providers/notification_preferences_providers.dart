import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/notification_preferences_remote_data_source.dart';
import '../../data/repositories/notification_preferences_repository_impl.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

// ── Infrastructure providers ───────────────────────────────────────────────────

final notificationPreferencesDataSourceProvider =
    Provider<NotificationPreferencesRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);

  return NotificationPreferencesRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
  );
});

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>((ref) {
  final networkInfo = ref.read(networkInfoProvider);
  final remoteDataSource =
      ref.read(notificationPreferencesDataSourceProvider);

  return NotificationPreferencesRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

// ── Notifier ───────────────────────────────────────────────────────────────────

/// Maneja el estado de las preferencias de notificación del usuario.
///
/// - Al construirse hace GET al servidor (offline-first: cae a caché si no hay red).
/// - [update] aplica optimistic update: actualiza UI inmediatamente, llama PATCH
///   al backend y revierte si falla.
class NotificationPreferencesNotifier
    extends AutoDisposeAsyncNotifier<NotificationPreferences> {
  static const _tag = 'NotifPrefsNotifier';

  @override
  Future<NotificationPreferences> build() async {
    // Solo refrescar si hay usuario autenticado.
    final userId = await ref.watch(
      authNotifierProvider.selectAsync((user) => user?.id),
    );
    if (userId == null) return const NotificationPreferences.defaults();

    final result = await ref
        .read(notificationPreferencesRepositoryProvider)
        .getPreferences();

    return result.fold(
      (failure) {
        AppLogger.w(
          'Error al cargar preferencias: ${failure.message}',
          tag: _tag,
        );
        // Fallback a defaults en vez de propagar error — la UI no debe romperse
        // si el servidor no responde al abrir settings.
        return const NotificationPreferences.defaults();
      },
      (prefs) => prefs,
    );
  }

  /// Actualiza una preferencia con optimistic update.
  ///
  /// [delta] es un mapa con los campos a cambiar (ej. `{'master': false}`).
  /// El servidor aplica cascada si master=false; el estado local se reemplaza
  /// con la respuesta completa del servidor.
  ///
  /// Retorna null en éxito o un mensaje de error localizado.
  Future<String?> patch(Map<String, bool> delta) async {
    final previous = state.valueOrNull;
    if (previous == null) return 'No hay preferencias cargadas';

    // Optimistic update — aplicar delta localmente de forma inmediata.
    final optimistic = _applyDelta(previous, delta);
    state = AsyncData(optimistic);

    final result = await ref
        .read(notificationPreferencesRepositoryProvider)
        .updatePreferences(delta);

    return result.fold(
      (failure) {
        // Revertir al estado anterior si el backend falla.
        state = AsyncData(previous);
        AppLogger.w(
          'Preferencia revertida tras error del servidor: ${failure.message}',
          tag: _tag,
        );
        return failure.message;
      },
      (serverPrefs) {
        // Reemplazar con el estado canónico del servidor (incluye cascada
        // master=false → subcategorías=false).
        state = AsyncData(serverPrefs);
        return null;
      },
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  NotificationPreferences _applyDelta(
    NotificationPreferences current,
    Map<String, bool> delta,
  ) {
    return current.copyWith(
      master: delta['master'],
      activities: delta['activities'],
      achievements: delta['achievements'],
      approvals: delta['approvals'],
      invitations: delta['invitations'],
      reminders: delta['reminders'],
    );
  }
}

/// Provider singleton para las preferencias de notificación.
///
/// autoDispose: se destruye cuando settings_view sale del árbol, lo que
/// fuerza un GET fresco la próxima vez que el usuario abre settings.
final notificationPreferencesProvider = AsyncNotifierProvider.autoDispose<
    NotificationPreferencesNotifier, NotificationPreferences>(
  NotificationPreferencesNotifier.new,
);
