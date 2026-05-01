import '../entities/biometric_capability.dart';
import '../entities/biometric_settings.dart';

/// Contrato de repositorio para autenticación biométrica.
///
/// - [getCapability] evalúa hardware + enrolamiento del dispositivo.
/// - [readSettings] / [saveSettings] persisten solo el flag de opt-in
///   y la fecha de enrolamiento — NUNCA datos biométricos.
/// - [authenticate] delega en `local_auth`. Debe forzar revalidación
///   en cada llamada (authenticationValidityDuration = 0 donde aplique).
abstract class BiometricRepository {
  Future<BiometricCapability> getCapability();

  Future<BiometricSettings> readSettings();
  Future<void> saveSettings(BiometricSettings settings);
  Future<void> clearSettings();

  /// Devuelve `true` si el usuario se autenticó correctamente.
  /// `reason` es la cadena que se muestra al usuario en el prompt nativo.
  Future<bool> authenticate({required String reason});

  /// Detiene cualquier prompt biométrico pendiente (útil en dispose).
  Future<void> stopAuthentication();
}
