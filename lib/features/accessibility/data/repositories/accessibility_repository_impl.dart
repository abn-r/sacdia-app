import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/accessibility_settings.dart';
import '../../domain/repositories/accessibility_repository.dart';

/// Implementación basada en [SharedPreferences].
///
/// Patrón idéntico a [ThemeNotifier]: lectura síncrona desde la instancia ya
/// cargada en `main()`, escritura async. No hay backend sync en MVP.
class AccessibilityRepositoryImpl implements AccessibilityRepository {
  final SharedPreferences _prefs;

  AccessibilityRepositoryImpl(this._prefs);

  @override
  AccessibilitySettings load() {
    final rawTextSize = _prefs.getString(AppConstants.accessibilityTextSizeKey);
    final highContrast =
        _prefs.getBool(AppConstants.accessibilityHighContrastKey) ?? false;
    final reduceMotion =
        _prefs.getBool(AppConstants.accessibilityReduceMotionKey) ?? false;

    return AccessibilitySettings(
      textSize: TextSizeOption.fromStorage(rawTextSize),
      highContrast: highContrast,
      reduceMotion: reduceMotion,
    );
  }

  @override
  Future<void> save(AccessibilitySettings settings) async {
    await Future.wait([
      _prefs.setString(
        AppConstants.accessibilityTextSizeKey,
        settings.textSize.storageValue,
      ),
      _prefs.setBool(
        AppConstants.accessibilityHighContrastKey,
        settings.highContrast,
      ),
      _prefs.setBool(
        AppConstants.accessibilityReduceMotionKey,
        settings.reduceMotion,
      ),
    ]);
  }
}
