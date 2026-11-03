import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';

/// Guard del design system v2 (`DESIGN-SYSTEM.md`, «Design token guard»).
///
/// Escanea `lib/` y falla si aparece un tamaño de fuente o un radio escrito
/// a mano, o un `Color(0x…)` nuevo. Los valores viven en `lib/core/theme/`:
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
      path.startsWith(
          'lib/features/virtual_card/presentation/widgets/credencial/');
}

/// `Color(0x…)` que ya existían al adoptar el DS v2, por archivo.
///
/// Es un trinquete: un archivo no puede tener más que su cifra, y cuando
/// migras colores a tokens hay que bajarla (el test avisa si sobra).
const colorLiteralBaseline = <String, int>{
  'lib/core/animations/celebration_overlay.dart': 3,
  'lib/core/notifications/push_notification_service.dart': 8,
  'lib/core/widgets/sac_image_viewer.dart': 2,
  'lib/core/widgets/sac_top_bar.dart': 2,
  'lib/features/achievements/presentation/views/achievement_detail_sheet.dart':
      5,
  'lib/features/achievements/presentation/widgets/achievement_badge.dart': 22,
  'lib/features/activities/presentation/views/activity_detail_view.dart': 1,
  'lib/features/activities/presentation/widgets/activities_loading_skeleton.dart':
      8,
  'lib/features/activities/presentation/widgets/activity_attendees_section.dart':
      16,
  'lib/features/activities/presentation/widgets/activity_detail_skeleton.dart':
      4,
  'lib/features/auth/presentation/views/welcome_carousel_view.dart': 4,
  'lib/features/auth/presentation/widgets/welcome_carousel_world.dart': 28,
  'lib/features/classes/presentation/views/class_detail_with_progress_view.dart':
      1,
  'lib/features/classes/presentation/views/requirement_detail_view.dart': 3,
  'lib/features/classes/presentation/widgets/enroll_previous_class_skeleton.dart':
      12,
  'lib/features/dashboard/presentation/widgets/birthday_celebration.dart': 8,
  'lib/features/dashboard/presentation/widgets/current_class_card.dart': 1,
  'lib/features/evidence_folder/presentation/views/evidence_folder_view.dart':
      6,
  'lib/features/evidence_folder/presentation/widgets/evidence_folder_loading_skeleton.dart':
      10,
  'lib/features/finances/presentation/widgets/balance_header_card.dart': 3,
  'lib/features/finances/presentation/widgets/finance_line_chart.dart': 5,
  'lib/features/finances/presentation/widgets/finances_loading_skeleton.dart':
      9,
  'lib/features/finances/presentation/widgets/period_selector.dart': 2,
  'lib/features/finances/presentation/widgets/transaction_search_field.dart': 4,
  'lib/features/finances/presentation/widgets/transaction_tile.dart': 17,
  'lib/features/finances/presentation/widgets/transaction_type_tabs.dart': 4,
  'lib/features/honors/presentation/widgets/honor_badge_image.dart': 1,
  'lib/features/insurance/presentation/views/insurance_form_sheet.dart': 1,
  'lib/features/insurance/presentation/widgets/insurance_loading_skeleton.dart':
      8,
  'lib/features/materials/presentation/views/cart_view.dart': 1,
  'lib/features/materials/presentation/views/order_summary_view.dart': 1,
  'lib/features/monthly_reports/presentation/views/monthly_report_detail_view.dart':
      6,
  'lib/features/monthly_reports/presentation/views/monthly_reports_list_view.dart':
      6,
  'lib/features/monthly_reports/presentation/views/monthly_reports_visible_list_view.dart':
      8,
  'lib/features/post_registration/presentation/widgets/profile_photo_picker.dart':
      1,
  'lib/features/profile/presentation/views/edit_profile_view.dart': 1,
  'lib/features/profile/presentation/views/profile_view.dart': 1,
  'lib/features/rankings/presentation/screens/club_rankings_screen.dart': 8,
  'lib/features/rankings/presentation/utils/award_tier_presentation_extensions.dart':
      5,
  'lib/features/settings/presentation/widgets/language_picker_tile.dart': 11,
  'lib/features/units/presentation/views/member_of_month_history_view.dart': 7,
  'lib/features/units/presentation/views/units_list_view.dart': 8,
  'lib/features/virtual_card/presentation/views/virtual_card_view.dart': 2,
  'lib/features/virtual_card/presentation/widgets/virtual_card_qr_tile.dart': 2,
};

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

  test('ningún archivo suma Color(0x…) por encima de su línea base', () {
    final above = <String>[];
    final stale = <String>[];
    final seen = <String>{};
    codeLines.forEach((path, lines) {
      final count = lines
          .map((entry) => _colorLiteral.allMatches(entry.$2).length)
          .fold(0, (a, b) => a + b);
      final allowed = colorLiteralBaseline[path] ?? 0;
      if (count > 0 || allowed > 0) seen.add(path);
      if (count > allowed) {
        above.add('$path: $count (línea base $allowed)');
      } else if (count < allowed) {
        stale.add('$path: baja la línea base a $count');
      }
    });
    for (final path in colorLiteralBaseline.keys) {
      if (!seen.contains(path)) stale.add('$path: ya no existe, quítalo');
    }
    expect(
      above,
      isEmpty,
      reason: 'Usa context.sac, SacAccent o un *_tokens.dart de la feature.',
    );
    expect(stale, isEmpty, reason: 'Actualiza colorLiteralBaseline.');
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
