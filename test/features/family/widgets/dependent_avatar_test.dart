import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/features/family/presentation/widgets/dependent_avatar.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Future<void> pump(WidgetTester tester, ThemeData theme) => tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: DependentAvatar(name: 'Ana')),
        ),
      );

  Color circleOf(WidgetTester tester) {
    final container = tester.widget<Container>(
      find.descendant(
        of: find.byType(DependentAvatar),
        matching: find.byType(Container),
      ),
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  Color initialOf(WidgetTester tester) =>
      tester.widget<Text>(find.text('A')).style!.color!;

  testWidgets('the initial grows with the circle', (tester) async {
    double initialSizeAt(double size) =>
        tester.widget<Text>(find.text('A')).style!.fontSize!;

    for (final size in const [36.0, 42.0, 64.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(body: DependentAvatar(name: 'Ana', size: size)),
        ),
      );
      expect(
        initialSizeAt(size),
        closeTo(size * kDependentAvatarInitialRatio, 0.001),
        reason: '$size',
      );
    }
  });

  testWidgets('in light the circle is the accent pastel', (tester) async {
    await pump(tester, AppTheme.lightTheme);
    final accent = SacAccent.of(tester.element(find.text('A')));

    expect(circleOf(tester), accent.light);
    expect(initialOf(tester), accent.dark);
  });

  testWidgets(
      'in dark the circle is the accent tint, not the pastel, and the '
      'initial reads on it', (tester) async {
    await pump(tester, AppTheme.darkTheme);
    final context = tester.element(find.text('A'));
    final accent = SacAccent.of(context);
    final tone = SacTonePalette.of(context, SacTone.accent);

    expect(circleOf(tester), isNot(accent.light));
    expect(circleOf(tester), tone.container);
    expect(circleOf(tester).computeLuminance(), lessThan(0.1));
    expect(
      _contrast(initialOf(tester), circleOf(tester)),
      greaterThanOrEqualTo(4.5),
    );
  });
}
