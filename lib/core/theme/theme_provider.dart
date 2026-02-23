import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/providers/storage_provider.dart';

/// Notifier para manejar el tema de la aplicación.
/// El estado ES el ThemeMode actual.
class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final saved = prefs.getString(AppConstants.themeKey);
    if (saved == 'light') return ThemeMode.light;
    if (saved == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  /// Cambia al tema claro
  Future<void> setLightTheme() async {
    state = ThemeMode.light;
    await ref.read(sharedPreferencesProvider).setString(AppConstants.themeKey, 'light');
  }

  /// Cambia al tema oscuro
  Future<void> setDarkTheme() async {
    state = ThemeMode.dark;
    await ref.read(sharedPreferencesProvider).setString(AppConstants.themeKey, 'dark');
  }

  /// Cambia al tema del sistema
  Future<void> setSystemTheme() async {
    state = ThemeMode.system;
    await ref.read(sharedPreferencesProvider).setString(AppConstants.themeKey, 'system');
  }

  /// Alterna entre tema claro y oscuro
  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      await setDarkTheme();
    } else {
      await setLightTheme();
    }
  }
}

final themeNotifierProvider = NotifierProvider<ThemeNotifier, ThemeMode>(() {
  return ThemeNotifier();
});
