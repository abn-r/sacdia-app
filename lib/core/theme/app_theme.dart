import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Clase que define los temas de la aplicación
class AppTheme {
  AppTheme._();

  /// Tema claro personalizado
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        secondary: AppColors.secondaryTeal,
        onSecondary: Colors.white,
        background: AppColors.lightBackground,
        surface: AppColors.lightSurface,
        error: AppColors.error,
      ),
      
      // Estilo de texto
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.lightText),
        displayMedium: TextStyle(color: AppColors.lightText),
        displaySmall: TextStyle(color: AppColors.lightText),
        headlineLarge: TextStyle(color: AppColors.lightText),
        headlineMedium: TextStyle(color: AppColors.lightText),
        headlineSmall: TextStyle(color: AppColors.lightText),
        titleLarge: TextStyle(color: AppColors.lightText),
        titleMedium: TextStyle(color: AppColors.lightText),
        titleSmall: TextStyle(color: AppColors.lightText),
        bodyLarge: TextStyle(color: AppColors.lightText),
        bodyMedium: TextStyle(color: AppColors.lightText),
        bodySmall: TextStyle(color: AppColors.lightTextSecondary),
        labelLarge: TextStyle(color: AppColors.lightText),
        labelMedium: TextStyle(color: AppColors.lightText),
        labelSmall: TextStyle(color: AppColors.lightTextSecondary),
      ),
      
      // AppBar estilo
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      
      // Card estilo
      cardTheme: const CardThemeData(
        color: AppColors.lightSurface,
        elevation: 2,
        margin: EdgeInsets.all(8),
      ),
      
      // Botón estilo
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Botón texto estilo
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      // Campo de texto estilo
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.lightDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Divisor estilo
      dividerTheme: const DividerThemeData(
        color: AppColors.lightDivider,
        thickness: 1,
        space: 16,
      ),
      
      // Otros elementos personalizados
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkSurface,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Tema oscuro personalizado
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        secondary: AppColors.secondaryTeal,
        onSecondary: Colors.white,
        background: AppColors.darkBackground,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
      
      // Estilo de texto
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: AppColors.darkText),
        displayMedium: TextStyle(color: AppColors.darkText),
        displaySmall: TextStyle(color: AppColors.darkText),
        headlineLarge: TextStyle(color: AppColors.darkText),
        headlineMedium: TextStyle(color: AppColors.darkText),
        headlineSmall: TextStyle(color: AppColors.darkText),
        titleLarge: TextStyle(color: AppColors.darkText),
        titleMedium: TextStyle(color: AppColors.darkText),
        titleSmall: TextStyle(color: AppColors.darkText),
        bodyLarge: TextStyle(color: AppColors.darkText),
        bodyMedium: TextStyle(color: AppColors.darkText),
        bodySmall: TextStyle(color: AppColors.darkTextSecondary),
        labelLarge: TextStyle(color: AppColors.darkText),
        labelMedium: TextStyle(color: AppColors.darkText),
        labelSmall: TextStyle(color: AppColors.darkTextSecondary),
      ),
      
      // AppBar estilo
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
      ),
      
      // Card estilo
      cardTheme: const CardThemeData(
        color: AppColors.darkSurface,
        elevation: 2,
        margin: EdgeInsets.all(8),
      ),
      
      // Botón estilo
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      
      // Botón texto estilo
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      
      // Campo de texto estilo
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      
      // Divisor estilo
      dividerTheme: const DividerThemeData(
        color: AppColors.darkDivider,
        thickness: 1,
        space: 16,
      ),
      
      // Otros elementos personalizados
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightSurface,
        contentTextStyle: const TextStyle(color: AppColors.lightText),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
