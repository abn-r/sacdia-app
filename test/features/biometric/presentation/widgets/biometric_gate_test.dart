import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/biometric/domain/entities/biometric_settings.dart';
import 'package:sacdia_app/features/biometric/presentation/providers/biometric_provider.dart';
import 'package:sacdia_app/features/biometric/presentation/widgets/biometric_gate.dart';

void main() {
  group('shouldShowBiometricLock', () {
    test(
        'does not lock when biometric is enabled but no authenticated session exists',
        () {
      const state = BiometricState(
        settings: BiometricSettings(enabled: true),
        unlocked: false,
      );

      expect(
        shouldShowBiometricLock(
          biometricState: state,
          isAuthenticated: false,
        ),
        isFalse,
      );
    });

    test('locks when biometric is enabled and an authenticated session exists',
        () {
      const state = BiometricState(
        settings: BiometricSettings(enabled: true),
        unlocked: false,
      );

      expect(
        shouldShowBiometricLock(
          biometricState: state,
          isAuthenticated: true,
        ),
        isTrue,
      );
    });

    test('does not lock when the biometric session is already unlocked', () {
      const state = BiometricState(
        settings: BiometricSettings(enabled: true),
        unlocked: true,
      );

      expect(
        shouldShowBiometricLock(
          biometricState: state,
          isAuthenticated: true,
        ),
        isFalse,
      );
    });
  });
}
