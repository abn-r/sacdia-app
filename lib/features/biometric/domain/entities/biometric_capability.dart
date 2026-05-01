import 'package:local_auth/local_auth.dart';

/// Capacidad biométrica del dispositivo evaluada en runtime.
///
/// [deviceSupportsBiometric] indica que el hardware soporta biometría
/// (`local_auth.isDeviceSupported`) Y que hay al menos un tipo registrado
/// (`local_auth.canCheckBiometrics`).
///
/// [availableTypes] enumera los factores disponibles (face, fingerprint, iris).
/// Se deriva de [LocalAuthentication.getAvailableBiometrics].
class BiometricCapability {
  final bool deviceSupportsBiometric;
  final bool hasEnrolledBiometrics;
  final List<BiometricType> availableTypes;

  const BiometricCapability({
    required this.deviceSupportsBiometric,
    required this.hasEnrolledBiometrics,
    required this.availableTypes,
  });

  const BiometricCapability.unsupported()
      : deviceSupportsBiometric = false,
        hasEnrolledBiometrics = false,
        availableTypes = const [];

  /// Conveniente: true solo si es viable habilitar biometría en este dispositivo.
  bool get canEnable => deviceSupportsBiometric && hasEnrolledBiometrics;

  bool get hasFace => availableTypes.contains(BiometricType.face);
  bool get hasFingerprint => availableTypes.contains(BiometricType.fingerprint);
  bool get hasIris => availableTypes.contains(BiometricType.iris);
  bool get hasStrong => availableTypes.contains(BiometricType.strong);
  bool get hasWeak => availableTypes.contains(BiometricType.weak);
}
