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
