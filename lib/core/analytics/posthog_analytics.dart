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

String get _projectToken =>
    _tokenFromDefine.isNotEmpty ? _tokenFromDefine : _bundledProjectToken;

Future<void> setupPosthog() async {
  final token = _projectToken;
  if (token.isEmpty) {
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

/// Identifica a [userId] en PostHog.
///
/// Solo [AnalyticsPolicy] debe llamarlo: ahí se decide quién puede
/// identificarse. Un menor de 13 a 17 o un teléfono vinculado nunca lo hace
/// (FP3-30); `test/core/analytics/no_sentry_user_test.dart` falla si otro
/// archivo lo llama.
Future<void> identifyAnalyticsUser(String userId) async {
  if (!_ready || userId.isEmpty || userId == _identifiedUserId) {
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

NavigatorObserver createPosthogNavigatorObserver() => PosthogObserver();
