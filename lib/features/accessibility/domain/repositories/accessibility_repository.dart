import '../entities/accessibility_settings.dart';

/// Contrato de persistencia de preferencias de accesibilidad.
///
/// MVP: solo almacenamiento local (SharedPreferences). El sync con backend
/// queda para una fase posterior.
abstract class AccessibilityRepository {
  /// Lee las preferencias persistidas. Si no existen, retorna los defaults.
  AccessibilitySettings load();

  /// Persiste las preferencias completas.
  Future<void> save(AccessibilitySettings settings);
}
