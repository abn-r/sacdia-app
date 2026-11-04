import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

Future<void> _pump(WidgetTester tester, Brightness b, Widget badge) {
  return tester.pumpWidget(
    MaterialApp(
      theme: b == Brightness.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: Scaffold(body: Center(child: badge)),
    ),
  );
}

Color? _bg(WidgetTester tester) {
  final box = tester.widget<Container>(
    find.descendant(
      of: find.byType(SacBadge),
      matching: find.byType(Container),
    ),
  );
  return (box.decoration as BoxDecoration).color;
}

Color? _fg(WidgetTester tester) =>
    tester.widget<Text>(find.byType(Text)).style?.color;

void main() {
  final cases = <String, Widget>{
    'success': const SacBadge.success(label: 'x'),
    'warning': const SacBadge.warning(label: 'x'),
    'error': const SacBadge.error(label: 'x'),
    'info': const SacBadge.info(label: 'x'),
  };

  Color bgOf(SacColors c, String name) => switch (name) {
        'success' => c.successContainer,
        'warning' => c.warningContainer,
        'error' => c.errorContainer,
        _ => c.infoContainer,
      };
  Color fgOf(SacColors c, String name) => switch (name) {
        'success' => c.onSuccessContainer,
        'warning' => c.onWarningContainer,
        'error' => c.onErrorContainer,
        _ => c.onInfoContainer,
      };

  group('SacBadge status variants', () {
    for (final b in Brightness.values) {
      for (final entry in cases.entries) {
        testWidgets('${entry.key} uses container tokens in ${b.name}',
            (tester) async {
          await _pump(tester, b, entry.value);
          final c = SacColors(b);
          expect(_bg(tester), bgOf(c, entry.key));
          expect(_fg(tester), fgOf(c, entry.key));
        });
      }
    }

    testWidgets('light and dark resolve to different colors', (tester) async {
      await _pump(tester, Brightness.light, const SacBadge.success(label: 'x'));
      final light = _bg(tester);
      await _pump(tester, Brightness.dark, const SacBadge.success(label: 'x'));
      await tester.pumpAndSettle();
      expect(_bg(tester), isNot(light));
    });
  });

  group('SacBadge primary', () {
    testWidgets('dark mode tints over the dark surface, not white',
        (tester) async {
      await _pump(tester, Brightness.dark, const SacBadge(label: 'x'));
      final bg = _bg(tester)!;
      expect(bg.computeLuminance(), lessThan(0.2));
    });

    testWidgets('light mode keeps the accent tint', (tester) async {
      await _pump(tester, Brightness.light, const SacBadge(label: 'x'));
      expect(_bg(tester)!.computeLuminance(), greaterThan(0.6));
    });
  });
}
