import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/network/interceptors/client_user_agent_interceptor.dart';

/// The backend tags a session as iOS/Android by looking for "iPhone",
/// "iPad" or "Android" in the User-Agent.
void main() {
  test('an iPhone reports its family, iOS version and model', () {
    final ua = buildClientUserAgent(
      appVersion: '1.0.0',
      deviceFamily: 'iPhone',
      platform: 'iOS',
      osVersion: '26.0',
      model: 'iPhone17,1',
    );

    expect(ua, 'SACDIA/1.0.0 (iPhone; iOS 26.0; iPhone17,1)');
    expect(ua.toLowerCase(), contains('iphone'));
  });

  test('an Android phone reports Android and the model', () {
    final ua = buildClientUserAgent(
      appVersion: '1.0.0',
      platform: 'Android',
      osVersion: '15',
      model: 'Google Pixel 8',
    );

    expect(ua, 'SACDIA/1.0.0 (Android 15; Google Pixel 8)');
  });

  test('empty optional parts are left out', () {
    final ua = buildClientUserAgent(
      appVersion: '2.1.0',
      deviceFamily: '',
      platform: 'iOS',
      osVersion: '18.2',
    );

    expect(ua, 'SACDIA/2.1.0 (iOS 18.2)');
  });
}
