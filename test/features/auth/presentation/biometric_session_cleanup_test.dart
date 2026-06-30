import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('clearSessionScopedBiometricOptIn removes biometric app-lock settings',
      () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.biometricEnabledKey: true,
      AppConstants.biometricEnrolledAtKey: '2026-06-30T00:00:00.000',
      'unrelated_preference': true,
    });
    final prefs = await SharedPreferences.getInstance();

    await clearSessionScopedBiometricOptIn(prefs);

    expect(prefs.getBool(AppConstants.biometricEnabledKey), isNull);
    expect(prefs.getString(AppConstants.biometricEnrolledAtKey), isNull);
    expect(prefs.getBool('unrelated_preference'), isTrue);
  });
}
