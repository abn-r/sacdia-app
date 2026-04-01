import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// SACDIA Design System - ThemeData "Scout Vibrante"
///
/// Minimalista con fondos blancos, acentos vibrantes,
/// cards redondeadas (16px), botones (12px), inputs (12px).
class AppTheme {
  AppTheme._();

  // Constantes de diseño
  static const double radiusXS = 8.0;
  static const double radiusSM = 12.0;
  static const double radiusMD = 16.0;
  static const double radiusLG = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusFull = 100.0;

  static const double elevationNone = 0.0;
  static const double elevationSM = 1.0;
  static const double elevationMD = 2.0;

  /// Tema claro - fondos blancos, acentos indigo/emerald/amber
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      // SF Pro Text is native on iOS; falls back gracefully to system font on Android.
      fontFamily: '.SF Pro Text',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryLight,
        onPrimaryContainer: AppColors.primaryDark,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryLight,
        onSecondaryContainer: AppColors.secondaryDark,
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.accentLight,
        onTertiaryContainer: AppColors.accentDark,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorLight,
        onErrorContainer: AppColors.errorDark,
        surface: AppColors.lightSurface,
        onSurface: AppColors.lightText,
        onSurfaceVariant: AppColors.lightTextSecondary,
        outline: AppColors.lightBorder,
        outlineVariant: AppColors.lightBorderLight,
      ),

      scaffoldBackgroundColor: AppColors.lightBackground,

      // Tipografía
      textTheme: const TextTheme(
        // Display - Headers de pantalla principal (28px bold)
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.lightText,
        ),

        // Headline - Títulos de sección (20px semibold)
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),

        // Title - Títulos de cards (16px medium)
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),

        // Body - Contenido general (14px regular)
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.lightText,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.lightText,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.lightTextSecondary,
          height: 1.5,
        ),

        // Label - Botones, badges, chips
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextTertiary,
        ),
      ),

      // AppBar - blanco, limpio, sin elevación
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.lightText,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),

      // Cards - radius 16, borde sutil, sin shadow pesada
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: elevationNone,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          side: const BorderSide(color: AppColors.lightBorder, width: 1),
        ),
      ),

      // Botón primario elevado
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: elevationNone,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Botón outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Botón texto / ghost
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Filled button (para variantes)
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
        ),
      ),

      // Campos de texto - radius 12, borde sutil
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: AppColors.lightTextTertiary,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        selectedColor: AppColors.primaryLight,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.lightText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: const BorderSide(color: AppColors.lightBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.lightTextTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Navigation Bar (M3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.primaryLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.lightTextTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(
              color: AppColors.primary,
              size: 24,
            );
          }
          return const IconThemeData(
            color: AppColors.lightTextTertiary,
            size: 24,
          );
        }),
      ),

      // SnackBar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.lightText,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.lightText,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ListTile
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.lightTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.lightBorder;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.lightBorderLight,
        circularTrackColor: AppColors.lightBorderLight,
      ),
    );
  }

  /// Tema oscuro - Slate backgrounds, mismos acentos vibrantes
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      // SF Pro Text is native on iOS; falls back gracefully to system font on Android.
      fontFamily: '.SF Pro Text',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryDark,
        onSecondaryContainer: AppColors.secondaryLight,
        tertiary: AppColors.accent,
        onTertiary: Colors.white,
        tertiaryContainer: AppColors.accentDark,
        onTertiaryContainer: AppColors.accentLight,
        error: AppColors.error,
        onError: Colors.white,
        errorContainer: AppColors.errorDark,
        onErrorContainer: AppColors.errorLight,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        onSurfaceVariant: AppColors.darkTextSecondary,
        outline: AppColors.darkBorder,
        outlineVariant: AppColors.darkSurfaceVariant,
      ),

      scaffoldBackgroundColor: AppColors.darkBackground,

      // Tipografía - mismos estilos, colores dark
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.darkText,
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: AppColors.darkText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.darkText,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.darkText,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.darkText,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.darkText,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.darkTextSecondary,
          height: 1.5,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextTertiary,
        ),
      ),

      // AppBar dark
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),

      // Cards dark
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: elevationNone,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          side: const BorderSide(color: AppColors.darkBorder, width: 1),
        ),
      ),

      // Botones dark
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: elevationNone,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Input dark
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          color: AppColors.darkTextTertiary,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          color: AppColors.darkTextSecondary,
          fontSize: 14,
        ),
        floatingLabelStyle: const TextStyle(
          color: AppColors.primary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Chips dark
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: AppColors.primaryDark,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.darkText,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // Divider dark
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),

      // Bottom Navigation dark
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Navigation Bar dark
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.primaryDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Colors.white, size: 24);
          }
          return const IconThemeData(
            color: AppColors.darkText,
            size: 24,
          );
        }),
      ),

      // SnackBar dark
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.darkText,
        contentTextStyle: TextStyle(
          color: AppColors.darkBackground,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
      ),

      // Dialog dark
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.darkText,
        ),
      ),

      // Bottom Sheet dark
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ListTile dark
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSM),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // Switch dark
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.darkTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.darkBorder;
        }),
      ),

      // Checkbox dark
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),

      // FAB dark
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // Progress indicators dark
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.darkSurfaceVariant,
        circularTrackColor: AppColors.darkSurfaceVariant,
      ),
    );
  }
}
