import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';

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

  /// Quita el ink de Material (splash y mancha al mantener presionado).
  /// El feedback de presión vive en [SacPressable] / [SacInkWell] / [SacCard].
  static const WidgetStateProperty<Color?> _noOverlay =
      WidgetStatePropertyAll(Colors.transparent);

  static ButtonStyle withoutInk(ButtonStyle style) {
    return style.copyWith(
      splashFactory: NoSplash.splashFactory,
      overlayColor: _noOverlay,
    );
  }

  /// Tema claro - fondos blancos, acentos indigo/emerald/amber
  static ThemeData get lightTheme => buildLight(SacAccent.logoBlue);

  static ThemeData buildLight(SacAccent accent) {
    return ThemeData(
      brightness: Brightness.light,
      extensions: <ThemeExtension<dynamic>>[accent],
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      // SF Pro Text is native on iOS; falls back gracefully to system font on Android.
      fontFamily: '.SF Pro Text',
      colorScheme: ColorScheme.light(
        primary: accent.color,
        onPrimary: accent.onColor,
        primaryContainer: accent.light,
        onPrimaryContainer: accent.dark,
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
          color: AppColors.lightText,
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
        style: withoutInk(ElevatedButton.styleFrom(
          backgroundColor: accent.color,
          foregroundColor: accent.onColor,
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
        )),
      ),

      // Botón outlined
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withoutInk(OutlinedButton.styleFrom(
          foregroundColor: accent.color,
          side: BorderSide(color: accent.color, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        )),
      ),

      // Botón texto / ghost
      textButtonTheme: TextButtonThemeData(
        style: withoutInk(TextButton.styleFrom(
          foregroundColor: accent.color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        )),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: withoutInk(const ButtonStyle()),
      ),
      tabBarTheme: const TabBarThemeData(
        splashFactory: NoSplash.splashFactory,
        overlayColor: _noOverlay,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: withoutInk(const ButtonStyle()),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: withoutInk(const ButtonStyle()),
      ),

      // Filled button (para variantes)
      filledButtonTheme: FilledButtonThemeData(
        style: withoutInk(FilledButton.styleFrom(
          backgroundColor: accent.color,
          foregroundColor: accent.onColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
        )),
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
          borderSide: BorderSide(color: accent.color, width: 2),
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
        floatingLabelStyle: TextStyle(
          color: accent.color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceVariant,
        selectedColor: accent.light,
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        selectedItemColor: accent.color,
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
        indicatorColor: accent.light,
        surfaceTintColor: Colors.transparent,
        overlayColor: _noOverlay,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accent.color,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.lightTextTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: accent.color,
              size: 24,
            );
          }
          return IconThemeData(
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
        overlayColor: _noOverlay,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.lightTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent.color;
          return AppColors.lightBorder;
        }),
      ),

      // Checkbox
      checkboxTheme: CheckboxThemeData(
        overlayColor: _noOverlay,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent.color;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(color: AppColors.lightBorder, width: 1.5),
      ),

      // FloatingActionButton
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent.color,
        foregroundColor: accent.onColor,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // Progress indicators
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent.color,
        linearTrackColor: AppColors.lightBorderLight,
        circularTrackColor: AppColors.lightBorderLight,
      ),
    );
  }

  /// Tema oscuro - Slate backgrounds, mismos acentos vibrantes
  static ThemeData get darkTheme => buildDark(SacAccent.logoBlue);

  static ThemeData buildDark(SacAccent accent) {
    accent = accent.forBrightness(Brightness.dark);
    return ThemeData(
      brightness: Brightness.dark,
      extensions: <ThemeExtension<dynamic>>[accent],
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      // SF Pro Text is native on iOS; falls back gracefully to system font on Android.
      fontFamily: '.SF Pro Text',
      colorScheme: ColorScheme.dark(
        primary: accent.color,
        onPrimary: accent.onColor,
        primaryContainer: accent.dark,
        onPrimaryContainer: accent.light,
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
          color: AppColors.darkText,
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
        style: withoutInk(ElevatedButton.styleFrom(
          backgroundColor: accent.color,
          foregroundColor: accent.onColor,
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
        )),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withoutInk(OutlinedButton.styleFrom(
          foregroundColor: accent.color,
          side: BorderSide(color: accent.color, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        )),
      ),

      textButtonTheme: TextButtonThemeData(
        style: withoutInk(TextButton.styleFrom(
          foregroundColor: accent.color,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        )),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: withoutInk(const ButtonStyle()),
      ),
      tabBarTheme: const TabBarThemeData(
        splashFactory: NoSplash.splashFactory,
        overlayColor: _noOverlay,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: withoutInk(const ButtonStyle()),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: withoutInk(const ButtonStyle()),
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
          borderSide: BorderSide(color: accent.color, width: 2),
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
        floatingLabelStyle: TextStyle(
          color: accent.color,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Chips dark
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: accent.dark,
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: accent.color,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Navigation Bar dark
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: accent.dark,
        surfaceTintColor: Colors.transparent,
        overlayColor: _noOverlay,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            );
          }
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: AppColors.darkTextSecondary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: Colors.white, size: 24);
          }
          return IconThemeData(
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
        overlayColor: _noOverlay,
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.darkTextTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent.color;
          return AppColors.darkBorder;
        }),
      ),

      // Checkbox dark
      checkboxTheme: CheckboxThemeData(
        overlayColor: _noOverlay,
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent.color;
          return Colors.transparent;
        }),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
        side: const BorderSide(color: AppColors.darkBorder, width: 1.5),
      ),

      // FAB dark
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent.color,
        foregroundColor: accent.onColor,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // Progress indicators dark
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent.color,
        linearTrackColor: AppColors.darkSurfaceVariant,
        circularTrackColor: AppColors.darkSurfaceVariant,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // High-contrast + reduce-motion support (Accessibility feature)
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // Filosofía: ADITIVO. Los temas base ([lightTheme]/[darkTheme]) no se tocan.
  // Derivamos variantes WCAG AAA (≥7:1) aplicando `copyWith` sobre `ColorScheme`,
  // reforzando bordes (≥ 2.0) y eliminando transparencias. El motion-reducido
  // se aplica mediante un [PageTransitionsTheme] con un builder que devuelve
  // el child sin animar.

  static ThemeData get lightHighContrastTheme =>
      lightHighContrast(SacAccent.logoBlue);

  /// Tema claro alto contraste — superficie blanca pura, texto negro puro,
  /// bordes gruesos (2.0), sin transparencias. El acento se empuja hasta
  /// 4.5:1 contra blanco, conservando el tono elegido.
  static ThemeData lightHighContrast(SacAccent accent) {
    final base = buildLight(accent);
    final hc = accent.forHighContrast(Brightness.light);
    final hcScheme = base.colorScheme.copyWith(
      primary: hc.color,
      onPrimary: hc.onColor,
      secondary: AppColors.secondaryDark,
      onSecondary: Colors.white,
      error: AppColors.errorDark,
      onError: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
      onSurfaceVariant: Colors.black,
      outline: Colors.black,
      outlineVariant: Colors.black,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[hc],
      colorScheme: hcScheme,
      scaffoldBackgroundColor: Colors.white,
      cardTheme: base.cardTheme.copyWith(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.black,
        thickness: 2,
        space: 2,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withoutInk(OutlinedButton.styleFrom(
          foregroundColor: hc.color,
          side: const BorderSide(color: Colors.black, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        )),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: BorderSide(color: hc.color, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.errorDark, width: 3),
        ),
        hintStyle: const TextStyle(color: Colors.black87, fontSize: 14),
        labelStyle: const TextStyle(color: Colors.black, fontSize: 14),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.white,
        selectedColor: hc.color,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        side: const BorderSide(color: Colors.black, width: 2),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.black,
        displayColor: Colors.black,
      ),
    );
  }

  /// Tema oscuro alto contraste — negro puro, texto blanco puro,
  /// bordes gruesos (2.0), sin transparencias.
  static ThemeData get darkHighContrastTheme =>
      darkHighContrast(SacAccent.logoBlue);

  static ThemeData darkHighContrast(SacAccent accent) {
    final base = buildDark(accent);
    final hc = accent.forHighContrast(Brightness.dark);
    final hcScheme = base.colorScheme.copyWith(
      primary: hc.color,
      onPrimary: hc.onColor,
      secondary: AppColors.secondaryLight,
      onSecondary: Colors.black,
      error: AppColors.errorLight,
      onError: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
      onSurfaceVariant: Colors.white,
      outline: Colors.white,
      outlineVariant: Colors.white,
    );

    return base.copyWith(
      extensions: <ThemeExtension<dynamic>>[hc],
      colorScheme: hcScheme,
      scaffoldBackgroundColor: Colors.black,
      cardTheme: base.cardTheme.copyWith(
        color: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Colors.white,
        thickness: 2,
        space: 2,
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: withoutInk(OutlinedButton.styleFrom(
          foregroundColor: hc.color,
          side: const BorderSide(color: Colors.white, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSM),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        )),
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: Colors.black,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: BorderSide(color: hc.color, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.errorLight, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSM),
          borderSide: const BorderSide(color: AppColors.errorLight, width: 3),
        ),
        hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),
        labelStyle: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: Colors.black,
        selectedColor: hc.color,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }

  /// Aplica [_NoTransitionsBuilder] a todas las plataformas si
  /// `reduceMotion = true`. Cuando es falso, retorna el theme tal cual.
  static ThemeData _withMotionPreference(ThemeData theme, bool reduceMotion) {
    if (!reduceMotion) return theme;
    return theme.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _NoTransitionsBuilder(),
          TargetPlatform.iOS: _NoTransitionsBuilder(),
          TargetPlatform.linux: _NoTransitionsBuilder(),
          TargetPlatform.macOS: _NoTransitionsBuilder(),
          TargetPlatform.windows: _NoTransitionsBuilder(),
          TargetPlatform.fuchsia: _NoTransitionsBuilder(),
        },
      ),
    );
  }

  /// Resolver principal — devuelve el [ThemeData] correcto según preferencias
  /// de accesibilidad. Usado por `main.dart` para alimentar
  /// `MaterialApp.router.theme` / `darkTheme`.
  static ThemeData themeFor({
    required Brightness brightness,
    required bool highContrast,
    required bool reduceMotion,
    SacAccent accent = SacAccent.logoBlue,
  }) {
    final ThemeData base;
    if (brightness == Brightness.dark) {
      base = highContrast ? darkHighContrast(accent) : buildDark(accent);
    } else {
      base = highContrast ? lightHighContrast(accent) : buildLight(accent);
    }
    return _withMotionPreference(base, reduceMotion);
  }
}

/// [PageTransitionsBuilder] que omite cualquier animación de transición
/// entre rutas. Se combina con `MediaQuery.disableAnimations = true` para
/// cubrir tanto transiciones del [Navigator] como animaciones internas
/// de widgets (ver `core/animations/*`).
class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}
