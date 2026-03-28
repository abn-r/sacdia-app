import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../activities/presentation/providers/activities_providers.dart';
import '../../../dashboard/presentation/providers/dashboard_providers.dart';
import '../../../enrollment/presentation/providers/enrollment_providers.dart';
import '../../../honors/presentation/providers/honors_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

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
///   - dashboardNotifierProvider   AsyncNotifierProvider  (non-autoDispose)
///   - userHonorsProvider          FutureProvider         (non-autoDispose)
///   - clubContextProvider         FutureProvider         (non-autoDispose)
///   - profileNotifierProvider     AsyncNotifierProvider  (non-autoDispose)
///   - currentEnrollmentProvider   FutureProvider         (non-autoDispose)
///   - clubActivitiesProvider      FutureProvider.autoDispose + keepAlive (club-specific)
void clearUserStateOnLogout(WidgetRef ref) {
  ref.invalidate(dashboardNotifierProvider);
  ref.invalidate(userHonorsProvider);
  ref.invalidate(clubContextProvider);
  ref.invalidate(profileNotifierProvider);
  ref.invalidate(currentEnrollmentProvider);
  ref.invalidate(clubActivitiesProvider);

  AppLogger.i(
    'Estado de usuario limpiado (providers invalidados)',
    tag: 'LogoutCleanup',
  );
}
