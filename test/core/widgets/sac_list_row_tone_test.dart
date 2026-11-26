import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    );

Widget _darkHost(Widget child, {SacAccent accent = SacAccent.logoBlue}) =>
    MaterialApp(
      theme: AppTheme.buildDark(accent),
      home: Scaffold(body: child),
    );

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Color _tileColor(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(
      of: find.byType(SacListRowIcon),
      matching: find.byType(Container),
    ),
  );
  return (container.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('SacListRowIcon defaults to the accent tint (unchanged)',
      (tester) async {
    await tester.pumpWidget(
      _host(const SacListRowIcon(HugeIcons.strokeRoundedFolder01)),
    );
    final accent = SacAccent.of(tester.element(find.byType(SacListRowIcon)));
    expect(_tileColor(tester), accent.light);
  });

  testWidgets(
      'in dark the accent tile is a tint over the surface, not the pastel',
      (tester) async {
    await tester.pumpWidget(
      _darkHost(const SacListRowIcon(HugeIcons.strokeRoundedFolder01)),
    );
    final context = tester.element(find.byType(SacListRowIcon));
    final accent = SacAccent.of(context);
    final tile = _tileColor(tester);

    expect(tile, isNot(accent.light));
    expect(
      tile,
      Color.alphaBlend(
          accent.color.withValues(alpha: 0.2), context.sac.surface),
    );
    // A dark tile: closer to the surface than to white.
    expect(tile.computeLuminance(), lessThan(0.1));
  });

  testWidgets('in dark every accent keeps its icon readable on the tile',
      (tester) async {
    for (final accent in SacAccent.catalog) {
      await tester.pumpWidget(
        _darkHost(
          const SacListRowIcon(HugeIcons.strokeRoundedFolder01),
          accent: accent,
        ),
      );
      final palette = SacTonePalette.of(
        tester.element(find.byType(SacListRowIcon)),
        SacTone.accent,
      );
      expect(
        _contrast(palette.onContainer, palette.container),
        greaterThanOrEqualTo(3),
        reason: accent.id,
      );
    }
  });

  testWidgets('SacListRowIcon destructive keeps the error tint',
      (tester) async {
    await tester.pumpWidget(
      _host(const SacListRowIcon(
        HugeIcons.strokeRoundedFolder01,
        destructive: true,
      )),
    );
    final c = tester.element(find.byType(SacListRowIcon)).sac;
    expect(_tileColor(tester), c.errorContainer);
  });

  testWidgets('SacListRowIcon tone picks the matching container',
      (tester) async {
    for (final tone in SacTone.values) {
      await tester.pumpWidget(
        _host(SacListRowIcon(HugeIcons.strokeRoundedFolder01, tone: tone)),
      );
      final palette = SacTonePalette.of(
        tester.element(find.byType(SacListRowIcon)),
        tone,
      );
      expect(_tileColor(tester), palette.container, reason: '$tone');
    }
  });

  testWidgets('SacListRow subtitleWidget wins over the text subtitle',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const SacListRow(
          leading: SacListRowIcon(HugeIcons.strokeRoundedFolder01),
          title: 'Carpetas',
          subtitle: 'text',
          subtitleWidget: Text('widget'),
        ),
      ),
    );
    expect(find.text('widget'), findsOneWidget);
    expect(find.text('text'), findsNothing);
  });
}
