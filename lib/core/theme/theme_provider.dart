import 'package:flutter/material.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/storage/local_storage.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Proveedor para manejar el tema de la aplicación
class ThemeProvider extends ChangeNotifier {
  // Dependencia para el almacenamiento local
  final LocalStorage _localStorage;

  // El tema actual
  ThemeMode _themeMode = ThemeMode.system;

  ThemeProvider(this._localStorage) {
    _loadTheme();
  }

  /// Getter para el tema actual
  ThemeMode get themeMode => _themeMode;

  /// Getter para el ThemeData del tema claro
  ThemeData get lightTheme => AppTheme.lightTheme;

  /// Getter para el ThemeData del tema oscuro
  ThemeData get darkTheme => AppTheme.darkTheme;

  /// Método para cargar el tema guardado del almacenamiento local
  Future<void> _loadTheme() async {
    final savedTheme = await _localStorage.getString(AppConstants.themeKey);
    
    if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    
    notifyListeners();
  }

  /// Método para cambiar al tema claro
  Future<void> setLightTheme() async {
    _themeMode = ThemeMode.light;
    await _localStorage.saveString(AppConstants.themeKey, 'light');
    notifyListeners();
  }

  /// Método para cambiar al tema oscuro
  Future<void> setDarkTheme() async {
    _themeMode = ThemeMode.dark;
    await _localStorage.saveString(AppConstants.themeKey, 'dark');
    notifyListeners();
  }

  /// Método para cambiar al tema del sistema
  Future<void> setSystemTheme() async {
    _themeMode = ThemeMode.system;
    await _localStorage.saveString(AppConstants.themeKey, 'system');
    notifyListeners();
  }

  /// Método para alternar entre temas
  Future<void> toggleTheme() async {
    if (_themeMode == ThemeMode.light) {
      await setDarkTheme();
    } else {
      await setLightTheme();
    }
  }
}
