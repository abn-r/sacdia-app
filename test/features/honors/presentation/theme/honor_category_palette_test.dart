import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';

void main() {
  group('getCategoryPaintColor', () {
    test('should keep saturated fills like Artes Domésticas', () {
      expect(
        getCategoryPaintColor(categoryName: 'Artes Domésticas'),
        AppColors.catDomesticas,
      );
    });

    test('should use the border color when the fill is near white', () {
      expect(
        getCategoryPaintColor(categoryName: 'Estudio de la Naturaleza'),
        AppColors.catNaturalezaBorde,
      );
    });

    test('should keep dark fills like Actividades Recreativas', () {
      expect(
        getCategoryPaintColor(categoryName: 'Actividades Recreativas'),
        AppColors.catRecreativas,
      );
    });
  });

  group('onCategoryPaintColor', () {
    test('should use white text on saturated fills like Artes Domésticas', () {
      expect(
        onCategoryPaintColor(
          AppColors.catDomesticas,
          onNearWhite: const Color(0xFF111111),
        ),
        Colors.white,
      );
    });

    test('should use dark text on Estudio de la Naturaleza fill', () {
      const dark = Color(0xFF111111);
      expect(
        onCategoryPaintColor(AppColors.catNaturaleza, onNearWhite: dark),
        dark,
      );
    });
  });
}
