import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/edit_profile_avatar.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    ThemeData theme, {
    bool isBusy = false,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: EditProfileAvatar(
              name: 'Ana',
              avatarUrl: null,
              isBusy: isBusy,
              busyLabel: 'Subiendo',
              onTap: () {},
            ),
          ),
        ),
      );

  /// The circle behind the initial (no photo).
  Color circleOf(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find
            .ancestor(of: find.text('A'), matching: find.byType(ColoredBox))
            .first,
      )
      .color;

  Color initialOf(WidgetTester tester) =>
      tester.widget<Text>(find.text('A')).style!.color!;

  testWidgets('in light the circle keeps the soft accent surface',
      (tester) async {
    await pump(tester, AppTheme.lightTheme);
    final accent = SacAccent.of(tester.element(find.text('A')));

    expect(circleOf(tester), accent.surface);
    expect(initialOf(tester), accent.dark);
    expect(
      _contrast(initialOf(tester), circleOf(tester)),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets(
      'in dark the circle is the accent tint, not a pastel, and the initial '
      'reads on it', (tester) async {
    await pump(tester, AppTheme.darkTheme);
    final context = tester.element(find.text('A'));
    final accent = SacAccent.of(context);
    final tone = SacTonePalette.of(context, SacTone.accent);

    expect(circleOf(tester), isNot(accent.surface));
    expect(circleOf(tester), tone.container);
    expect(circleOf(tester).computeLuminance(), lessThan(0.1));
    expect(
      _contrast(initialOf(tester), circleOf(tester)),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('in dark the upload ring track is the accent tint',
      (tester) async {
    await pump(tester, AppTheme.darkTheme, isBusy: true);
    final context = tester.element(find.text('A'));
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );

    expect(
      ring.backgroundColor,
      SacTonePalette.of(context, SacTone.accent).container,
    );
    expect(ring.backgroundColor, isNot(SacAccent.of(context).light));
  });
}
