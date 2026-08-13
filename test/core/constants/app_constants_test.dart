import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';

void main() {
  group('resolveBaseUrl — debug/profile', () {
    test('falls back to the local development API URL by default', () {
      expect(AppConstants.baseUrl, 'http://localhost:3000/api/v1');
    });

    test('allows overriding the API URL when needed', () {
      expect(
        AppConstants.resolveBaseUrl(
          override: 'http://10.0.0.5:4000/api/v1',
        ),
        'http://10.0.0.5:4000/api/v1',
      );
    });
  });

  group('resolveBaseUrl — release', () {
    test('throws when API_BASE_URL is missing', () {
      expect(
        () => AppConstants.resolveBaseUrl(override: '', releaseMode: true),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('--dart-define=API_BASE_URL'),
        )),
      );
    });

    test('throws when the URL is not HTTPS', () {
      expect(
        () => AppConstants.resolveBaseUrl(
          override: 'http://api.sacdia.com/api/v1',
          releaseMode: true,
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('HTTPS'),
        )),
      );
    });

    test('accepts an HTTPS production URL', () {
      expect(
        AppConstants.resolveBaseUrl(
          override: 'https://api.sacdia.com/api/v1',
          releaseMode: true,
        ),
        'https://api.sacdia.com/api/v1',
      );
    });
  });
}
