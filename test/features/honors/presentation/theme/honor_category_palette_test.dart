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

  group('bandColorFor', () {
    test('holds 4.5:1 against white for every category in the palette', () {
      final names = {
        ...kCategoryColorByName.keys,
        ...kCategoryAccentColorByName.keys,
      };
      for (final name in names) {
        final band = bandColorFor(categoryName: name);
        expect(
          contrastOnWhite(band),
          greaterThanOrEqualTo(kBandMinContrastOnWhite),
          reason: name,
        );
      }
      for (final id in kCategoryColorById.keys) {
        expect(
          contrastOnWhite(bandColorFor(categoryId: id)),
          greaterThanOrEqualTo(kBandMinContrastOnWhite),
          reason: 'category id $id',
        );
      }
      // Unknown category falls back to the info color.
      expect(
        contrastOnWhite(bandColorFor()),
        greaterThanOrEqualTo(kBandMinContrastOnWhite),
      );
    });

    test('also holds for the raw paint and accent colors', () {
      final colors = [
        ...kCategoryColorByName.values,
        ...kCategoryAccentColorByName.values,
        ...kCategoryColorById.values,
      ];
      for (final color in colors) {
        expect(
          contrastOnWhite(darkenForWhiteText(color)),
          greaterThanOrEqualTo(kBandMinContrastOnWhite),
          reason: '$color',
        );
      }
    });

    test('leaves a color that already passes untouched', () {
      expect(
        bandColorFor(categoryName: 'ADRA'),
        AppColors.catAdra,
      );
      expect(
          darkenForWhiteText(AppColors.catMisioneras), AppColors.catMisioneras);
    });

    test('darkens a failing color and keeps its hue', () {
      // #248ABA is about 3.9:1 on white.
      const blue = AppColors.catHabilidadesManuales;
      expect(contrastOnWhite(blue), lessThan(kBandMinContrastOnWhite));
      final band = bandColorFor(categoryName: 'Artes y Actividades Manuales');
      expect(band, isNot(blue));
      expect(
        HSLColor.fromColor(band).hue,
        closeTo(HSLColor.fromColor(blue).hue, 6),
      );
    });

    test('near-white categories use the darkened accent color', () {
      final band = bandColorFor(categoryName: 'Estudio de la Naturaleza');
      expect(
        band,
        darkenForWhiteText(AppColors.catNaturalezaBorde),
      );
    });
  });
}
