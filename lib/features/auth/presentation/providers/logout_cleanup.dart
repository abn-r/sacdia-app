import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/app_bootstrap_provider.dart';
import '../../../../core/utils/app_logger.dart';

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
/// Llamar desde el widget inmediatamente después de que [AuthNotifier.signOut]
/// retorne `true`. Se ubica en un archivo separado de auth_providers.dart para
/// evitar importaciones circulares (los providers de features ya importan
/// auth_providers.dart).
///
/// Providers invalidados:
///   - dashboardNotifierProvider   AsyncNotifierProvider          (non-autoDispose)
///   - userHonorsProvider          FutureProvider.autoDispose     + keepAlive (user-specific)
///   - clubContextProvider         FutureProvider                 (non-autoDispose)
///   - profileNotifierProvider     AsyncNotifierProvider.autoDispose + keepAlive (user-specific)
///   - currentEnrollmentProvider   FutureProvider                 (non-autoDispose)
///   - currentClubSectionProvider  FutureProvider.autoDispose     + keepAlive (club-specific)
///   - clubActivitiesProvider      FutureProvider.autoDispose     + keepAlive (club-specific)
void clearUserStateOnLogout(WidgetRef ref) {
  for (final provider in userSpecificProviders) {
    ref.invalidate(provider);
  }
  ref.invalidate(appBootstrapProvider);

  AppLogger.i(
    'Estado de usuario limpiado (providers invalidados)',
    tag: 'LogoutCleanup',
  );
}
