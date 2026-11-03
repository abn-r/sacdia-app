import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';

/// Guard del design system v2 (`DESIGN-SYSTEM.md`, «Design token guard»).
///
/// Escanea `lib/` y falla si aparece un tamaño de fuente o un radio escrito
/// a mano, o un `Color(0x…)` fuera de un archivo de tokens. Los valores viven
/// en `lib/core/theme/`:
/// `SacFontSize` para la tipografía y `AppTheme.radius*` para los radios.
///
/// Una línea concreta puede quedar fuera con un comentario
/// `// ds-allow: <motivo>`. Los comentarios (`//`, `///`) no cuentan.

/// Archivos de arte o de tokens propios de una feature: definen sus valores.
bool isDesignTokenExempt(String path) {
  final name = path.split('/').last;
  return path.startsWith('lib/core/theme/') ||
      name.endsWith('_tokens.dart') ||
      name.contains('sprites') ||
      name.endsWith('.g.dart') ||
      name.endsWith('.freezed.dart') ||
      path ==
          'lib/features/auth/presentation/widgets/welcome_carousel_visuals.dart' ||
      path ==
          'lib/features/auth/presentation/widgets/welcome_carousel_world.dart' ||
      path.startsWith(
          'lib/features/virtual_card/presentation/widgets/credencial/');
}

final _fontSizeLiteral = RegExp(r'fontSize:\s*(\d+(?:\.\d+)?)');
final _radiusLiteral = RegExp(r'\b(?:Border)?Radius\.circular\(\s*\d');
final _colorLiteral = RegExp(r'Color\(0x');

/// Líneas de código de cada archivo de `lib/` sujeto al guard, sin
/// comentarios ni líneas marcadas con `ds-allow`.
Map<String, List<(int, String)>> _codeLinesByFile() {
  final result = <String, List<(int, String)>>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final path = file.path.replaceAll(r'\', '/');
    if (isDesignTokenExempt(path)) continue;
    final lines = <(int, String)>[];
    final raw = file.readAsLinesSync();
    for (var i = 0; i < raw.length; i++) {
      final line = raw[i];
      if (line.trimLeft().startsWith('//') || line.contains('ds-allow')) {
        continue;
      }
      lines.add((i + 1, line.split('//').first));
    }
    result[path] = lines;
  }
  return result;
}

void main() {
  final codeLines = _codeLinesByFile();

  test('no hay fontSize escritos a mano fuera de lib/core/theme', () {
    final offenders = <String>[];
    codeLines.forEach((path, lines) {
      for (final (number, code) in lines) {
        for (final match in _fontSizeLiteral.allMatches(code)) {
          if (double.parse(match.group(1)!) == 0) continue;
          offenders.add('$path:$number  ${code.trim()}');
        }
      }
    });
    expect(
      offenders,
      isEmpty,
      reason:
          'Usa textTheme o SacFontSize (lib/core/theme/sac_font_size.dart).',
    );
  });

  test('no hay radios escritos a mano fuera de lib/core/theme', () {
    final offenders = <String>[];
    codeLines.forEach((path, lines) {
      for (final (number, code) in lines) {
        if (_radiusLiteral.hasMatch(code)) {
          offenders.add('$path:$number  ${code.trim()}');
        }
      }
    });
    expect(
      offenders,
      isEmpty,
      reason: 'Usa AppTheme.radius* (lib/core/theme/app_theme.dart).',
    );
  });

  test('no hay Color(0x…) escritos a mano fuera de los archivos de tokens', () {
    final offenders = <String>[];
    codeLines.forEach((path, lines) {
      for (final (number, code) in lines) {
        if (_colorLiteral.hasMatch(code)) {
          offenders.add('$path:$number  ${code.trim()}');
        }
      }
    });
    expect(
      offenders,
      isEmpty,
      reason: 'Usa context.sac, AppColors, SacAccent o un *_tokens.dart '
          'de la feature.',
    );
  });

  test('el textTheme toma sus tamaños de SacFontSize', () {
    for (final theme in [
      AppTheme.buildLight(SacAccent.logoBlue),
      AppTheme.buildDark(SacAccent.logoBlue),
    ]) {
      final t = theme.textTheme;
      final expected = <(TextStyle?, double)>[
        (t.displayLarge, SacFontSize.displayLarge),
        (t.displayMedium, SacFontSize.displayMedium),
        (t.displaySmall, SacFontSize.displaySmall),
        (t.headlineLarge, SacFontSize.headlineLarge),
        (t.headlineMedium, SacFontSize.headlineMedium),
        (t.headlineSmall, SacFontSize.headlineSmall),
        (t.titleLarge, SacFontSize.titleLarge),
        (t.titleMedium, SacFontSize.titleMedium),
        (t.titleSmall, SacFontSize.titleSmall),
        (t.bodyLarge, SacFontSize.titleMedium),
        (t.bodyMedium, SacFontSize.bodyMedium),
        (t.bodySmall, SacFontSize.bodySmall),
        (t.labelLarge, SacFontSize.titleSmall),
        (t.labelMedium, SacFontSize.bodySmall),
        (t.labelSmall, SacFontSize.labelSmall),
      ];
      for (final (style, size) in expected) {
        expect(style?.fontSize, size);
      }
    }
  });
}
