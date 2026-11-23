import '../../features/auth/domain/entities/onboarding_mode.dart';
import '../../features/auth/domain/entities/principal_info.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/auth/domain/utils/authorization_utils.dart';
import 'route_names.dart';
import 'supervised_route_policy.dart';

/// Compuerta de rutas de una cuenta `panel_only` (su función se hace en el panel
/// web y la app no tiene tareas para ella).
///
/// Solo aplica a la cuenta de adulto normal en su propio perfil: el
/// `onboarding_mode` lo decide el servidor, y el adolescente supervisado, el
/// dispositivo vinculado, el liberado, el restringido y la cuenta sin fecha de
/// nacimiento tienen sus propias compuertas, que ganan. Mientras se actúa por
/// un dependiente la sesión es la del dependiente (modo `club`), así que no
/// aplica; al salir, el tutor vuelve aquí.
///
/// Lista blanca: la pantalla `/account/panel-only`, `/access-denied` y, solo
/// para una cuenta de tutor ([isGuardianAccount]), todo `/family`.
bool isPanelOnlyAccount(UserEntity user) =>
    user.onboardingMode == OnboardingMode.panelOnly &&
    user.actingFor == null &&
    user.mode == AccountMode.adult;

/// A dónde llevar a [user] según la compuerta de cuentas de solo panel cuando
/// va a [path], o `null` si puede seguir.
///
/// - Cuenta de solo panel: cualquier ruta fuera de la lista blanca va a
///   `/account/panel-only`.
/// - Cualquier otra cuenta que abra `/account/panel-only` (p. ej. el servidor le
///   asignó un club y pulsó «Comprobar de nuevo») va a su inicio.
String? panelOnlyRouteRedirect(UserEntity user, String path) {
  final normalized = _normalize(path);
  if (!isPanelOnlyAccount(user)) {
    if (normalized != RouteNames.panelOnlyAccount) return null;
    return accountHomeFor(
      user.mode,
      needsPostRegistration: userNeedsPostRegistration(user),
      releaseFrozen: user.isReleaseFrozen,
    );
  }
  if (normalized == RouteNames.panelOnlyAccount ||
      normalized == RouteNames.accessDenied) {
    return null;
  }
  if (isGuardianAccount(user) && _hasPrefix(normalized, RouteNames.family)) {
    return null;
  }
  return RouteNames.panelOnlyAccount;
}

String _normalize(String path) => path.length > 1 && path.endsWith('/')
    ? path.substring(0, path.length - 1)
    : path;

bool _hasPrefix(String path, String prefix) =>
    path == prefix || path.startsWith('$prefix/');
