import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// Same PostHog US project as sacdia-admin.
///
/// Override with `--dart-define=POSTHOG_PROJECT_TOKEN=phc_...` when a build
/// should talk to a different project. The bundled value is the public
/// project token, not a personal API key.
const _tokenFromDefine = String.fromEnvironment('POSTHOG_PROJECT_TOKEN');
const _bundledProjectToken = 'phc_sr62nuGVMV9T8fSqPtbwD8yQEvYu5hPYCCT4X9jAtZr5';

const _posthogHost = 'https://us.i.posthog.com';

bool _ready = false;
String? _identifiedUserId;

/// `true` mientras esta instalación es el teléfono vinculado de un menor de 13:
/// ni se inicializa PostHog ni se captura nada (privacidad §6.1: ninguna
/// analítica personalizada a esa edad, FP3-52).
bool _blockedForDevice = false;

String get _projectToken =>
    _tokenFromDefine.isNotEmpty ? _tokenFromDefine : _bundledProjectToken;

Future<void> setupPosthog() async {
  final token = _projectToken;
  if (token.isEmpty || _ready || _blockedForDevice) {
    return;
  }

  final config = PostHogConfig(token);
  config.host = _posthogHost;
  config.debug = kDebugMode;
  config.sessionReplay = false;
  config.personProfiles = PostHogPersonProfiles.identifiedOnly;
  await Posthog().setup(config);
  _ready = true;
}

/// ¿Esta instalación ya identificó a alguien en PostHog?
bool get analyticsUserIdentified => _identifiedUserId != null;

/// ¿Se bloqueó la analítica por ser un teléfono vinculado?
bool get analyticsBlockedForDevice => _blockedForDevice;

/// Marca la instalación como teléfono vinculado ANTES de inicializar PostHog
/// (arranque en frío): `setupPosthog` pasa a ser un no-op.
void blockAnalyticsForDevice() {
  _blockedForDevice = true;
}

/// Teléfono de un menor: PostHog deja de capturar (sin identificar, sin
/// eventos, sin pantallas) y se olvida cualquier identidad previa. FCM no se
/// toca.
Future<void> disableAnalyticsForDevice() async {
  _blockedForDevice = true;
  _identifiedUserId = null;
  if (!_ready) {
    return;
  }
  await Posthog().reset();
  await Posthog().optOut();
}

/// La sesión de dispositivo terminó: esta instalación vuelve a ser de cuentas.
/// Se reactiva la captura (o se inicializa PostHog si el arranque lo omitió).
Future<void> enableAnalyticsAfterDevice() async {
  if (!_blockedForDevice) {
    return;
  }
  _blockedForDevice = false;
  if (_ready) {
    await Posthog().optIn();
    return;
  }
  await setupPosthog();
}

/// ¿Puede capturar PostHog ahora? (observador de pantallas.)
bool get analyticsCaptureAllowed => _ready && !_blockedForDevice;

/// Identifica a [userId] en PostHog.
///
/// Solo [AnalyticsPolicy] debe llamarlo: ahí se decide quién puede
/// identificarse. Un menor de 13 a 17 o un teléfono vinculado nunca lo hace
/// (FP3-30); `test/core/analytics/no_sentry_user_test.dart` falla si otro
/// archivo lo llama.
Future<void> identifyAnalyticsUser(String userId) async {
  if (!_ready ||
      _blockedForDevice ||
      userId.isEmpty ||
      userId == _identifiedUserId) {
    return;
  }

  await Posthog().identify(userId: userId);
  _identifiedUserId = userId;
}

Future<void> resetAnalyticsUser() async {
  if (!_ready) {
    return;
  }

  _identifiedUserId = null;
  await Posthog().reset();
}

NavigatorObserver createPosthogNavigatorObserver() => _GatedPosthogObserver();

/// Observador de pantallas que no captura nada mientras la instalación es un
/// teléfono vinculado (o PostHog no se inicializó).
class _GatedPosthogObserver extends PosthogObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!analyticsCaptureAllowed) return;
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (!analyticsCaptureAllowed) return;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (!analyticsCaptureAllowed) return;
    super.didPop(route, previousRoute);
  }
}
