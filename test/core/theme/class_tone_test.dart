import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/class_tone.dart';

const _classColors = <String, Color>{
  'Corderitos': AppColors.colorCorderitos,
  'Aves Madrugadoras': AppColors.colorCastores,
  'Abejitas Industriosas': AppColors.colorAbejas,
  'Rayos de Sol': AppColors.colorRayos,
  'Constructores': AppColors.colorConstructores,
  'Manos Ayudadoras': AppColors.colorManos,
  'Amigo': AppColors.colorAmigo,
  'Compañero': AppColors.colorCompanero,
  'Explorador': AppColors.colorExplorador,
  'Orientador': AppColors.colorOrientador,
  'Viajero': AppColors.colorViajero,
  'Guía': AppColors.colorGuia,
  'Guía Mayor': AppColors.colorGuiaMayor,
  'fallback': AppColors.primary,
};

void main() {
  for (final mode in [
    (Brightness.light, AppColors.lightSurface),
    (Brightness.dark, AppColors.darkSurface),
  ]) {
    group('${mode.$1.name} mode', () {
      for (final entry in _classColors.entries) {
        test('${entry.key} text reads on its tint and on the card', () {
          final tone = ClassTone.resolve(
            entry.value,
            surface: mode.$2,
            brightness: mode.$1,
          );

          expect(
            ClassTone.contrast(tone.onContainer, tone.container),
            greaterThanOrEqualTo(ClassTone.minContrast),
          );
          expect(
            ClassTone.contrast(tone.onContainer, mode.$2),
            greaterThanOrEqualTo(ClassTone.minContrast),
          );
        });
      }
    });
  }

  test('the text keeps the class hue', () {
    final tone = ClassTone.resolve(
      AppColors.colorViajero,
      surface: AppColors.lightSurface,
      brightness: Brightness.light,
    );
    final hue = HSLColor.fromColor(tone.onContainer).hue;
    expect(hue, closeTo(HSLColor.fromColor(AppColors.colorViajero).hue, 2));
  });
}
