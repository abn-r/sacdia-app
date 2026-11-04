import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('SacButton.text has >= 44dp tap target and fires onPressed',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        _host(SacButton.text(text: 'Ver todo', onPressed: () => taps++)));
    expect(tester.getSize(find.byType(SacButton)).height,
        greaterThanOrEqualTo(44));
    // Tap just inside the expanded hit area, outside the 36dp visual.
    final rect = tester.getRect(find.byType(SacButton));
    await tester.tapAt(Offset(rect.center.dx, rect.top + 2));
    expect(taps, 1);
  });

  testWidgets('every SacButton size has >= 44dp height', (tester) async {
    for (final size in SacButtonSize.values) {
      await tester.pumpWidget(
          _host(SacButton(text: 'X', size: size, onPressed: () {})));
      expect(tester.getSize(find.byType(SacButton)).height,
          greaterThanOrEqualTo(44),
          reason: '$size');
    }
  });
}
