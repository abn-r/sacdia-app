import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';

void main() {
  test('uses the local development API URL for physical devices by default',
      () {
    expect(AppConstants.baseUrl, 'http://192.168.1.14:3000/api/v1');
  });

  test('allows overriding the API URL when needed', () {
    expect(
      AppConstants.resolveBaseUrl(
        override: 'http://10.0.0.5:4000/api/v1',
      ),
      'http://10.0.0.5:4000/api/v1',
    );
  });
}
