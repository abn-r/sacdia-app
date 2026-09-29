import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

void main() {
  group('AppTheme AppBar titles', () {
    test('use semantic text color in light theme', () {
      expect(
        AppTheme.lightTheme.appBarTheme.titleTextStyle?.color,
        AppColors.lightText,
      );
    });

    test('use semantic text color in dark theme', () {
      expect(
        AppTheme.darkTheme.appBarTheme.titleTextStyle?.color,
        AppColors.darkText,
      );
    });
  });

  group('AppTheme press feedback', () {
    test('drops the Material hold wash in light and dark', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(theme.splashFactory, NoSplash.splashFactory);
        expect(theme.highlightColor, Colors.transparent);
        expect(theme.splashColor, Colors.transparent);
        expect(
          theme.iconButtonTheme.style?.splashFactory,
          NoSplash.splashFactory,
        );
      }
    });
  });
}
