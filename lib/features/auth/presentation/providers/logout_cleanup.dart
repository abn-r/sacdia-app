import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/analytics/posthog_analytics.dart';
import '../../../../core/auth/acting_for_session.dart';
import '../../../../core/providers/app_bootstrap_provider.dart';
import '../../../../core/storage/json_file_cache.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../providers/json_file_cache_provider.dart';
import '../../../../providers/storage_provider.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../home_widgets/next_activity_widget_sync.dart';
import 'acting_providers.dart';
import 'profile_scope_purge.dart';

/// Invalida providers con estado de usuario al cerrar sesión.
///
/// Incluye dos categorías:
///   1. Providers sin `autoDispose` — persisten indefinidamente y son el vector
///      principal de filtración de datos entre sesiones.
///   2. Providers con `autoDispose` + `keepAlive` que contengan datos
///      específicos del usuario/club — el `keepAlive` impide la auto-destrucción
///      al perder listeners, así que requieren invalidación explícita.
///
/// Los providers `autoDispose` + `keepAlive` con datos de catálogo estático
/// (clubTypes, districts, etc.) NO se invalidan aquí porque son datos de
/// referencia agnósticos al usuario.
///
/// Ejecutar desde un provider estable, no desde una pantalla que puede ser
/// desmontada por GoRouter durante logout. Se ubica en un archivo separado de
/// auth_providers.dart para evitar importaciones circulares (los providers de
/// features ya importan auth_providers.dart).
///
/// Providers invalidados:
///   - dashboardNotifierProvider   AsyncNotifierProvider          (non-autoDispose)
///   - userHonorsProvider          FutureProvider.autoDispose     + keepAlive (user-specific)
///   - clubContextProvider         FutureProvider                 (non-autoDispose)
///   - profileNotifierProvider     AsyncNotifierProvider.autoDispose + keepAlive (user-specific)
///   - currentEnrollmentProvider   FutureProvider                 (non-autoDispose)
///   - currentClubSectionProvider  FutureProvider.autoDispose     + keepAlive (club-specific)
///   - clubActivitiesProvider      FutureProvider.autoDispose     + keepAlive (club-specific)
///   - userClassesProvider         FutureProvider.autoDispose     + keepAlive (user-specific)
///
/// También cierra el modo "actuar por" (FP-53): la sesión de memoria, la foto
/// del tutor y el aviso pendiente se borran, y la bandera `acting_dirty` baja
/// porque los cachés de disco se purgan aquí mismo. Se invalida todo el
/// registro de perfil (no solo [userSpecificProviders]) para que el siguiente
/// inicio de sesión no herede providers `keepAlive` del usuario anterior.
void clearUserStateOnLogout(Ref ref) {
  ref.read(actingForSessionProvider).exit();
  ref.read(guardianUserProvider.notifier).state = null;
  ref.read(actingNoticeProvider.notifier).state = null;
  unawaited(
    ref.read(sharedPreferencesProvider).setBool(kActingDirtyPrefsKey, false),
  );
  purgeProfileScopeProviders(ref);
  ref.invalidate(appBootstrapProvider);
  _clearScopedDashboardCache(ref);
  unawaited(resetAnalyticsUser());
  unawaited(clearNextActivityWidget());
  unawaited(
    ref.read(jsonFileCacheProvider).deleteByPrefix(kUserClassesCacheKeyPrefix),
  );

  AppLogger.i(
    'Estado de usuario limpiado (providers invalidados)',
    tag: 'LogoutCleanup',
  );
}

void _clearScopedDashboardCache(Ref ref) {
  final storage = ref.read(localStorageProvider);
  unawaited(clearDashboardSummaryDiskCache(storage));
}
