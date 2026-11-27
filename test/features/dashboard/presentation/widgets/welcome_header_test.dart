import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/welcome_header.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required int unreadCount,
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: WelcomeHeader(
            userName: 'Ana Test',
            unreadNotificationsCount: unreadCount,
            onNotificationsTap: () {},
          ),
        ),
      ),
    );
  }

  /// The fallback circle behind the initial (no photo).
  Container fallbackOf(WidgetTester tester) => tester.widget<Container>(
        find
            .ancestor(of: find.text('A'), matching: find.byType(Container))
            .first,
      );

  Color initialColorOf(WidgetTester tester) =>
      tester.widget<Text>(find.text('A')).style!.color!;

  testWidgets('shows unread notification badge when count is positive',
      (tester) async {
    await pumpHeader(tester, unreadCount: 7);

    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('hides unread notification badge when count is zero',
      (tester) async {
    await pumpHeader(tester, unreadCount: 0);

    expect(find.text('0'), findsNothing);
  });

  testWidgets(
      'in light the avatar fallback keeps the accent pastel, with the '
      'initial in the shade that reads on it', (tester) async {
    await pumpHeader(tester, unreadCount: 0, theme: AppTheme.lightTheme);
    final accent = SacAccent.of(tester.element(find.text('A')));

    expect(fallbackOf(tester).color, accent.light);
    expect(initialColorOf(tester), accent.dark);
  });

  testWidgets(
      'in dark the avatar fallback is the accent tint, not the pastel, and '
      'the initial stays readable', (tester) async {
    await pumpHeader(tester, unreadCount: 0, theme: AppTheme.darkTheme);
    final context = tester.element(find.text('A'));
    final accent = SacAccent.of(context);
    final tone = SacTonePalette.of(context, SacTone.accent);
    final background = fallbackOf(tester).color!;
    final initial = initialColorOf(tester);

    expect(background, isNot(accent.light));
    expect(background, tone.container);
    expect(initial, tone.onContainer);
    expect(background.computeLuminance(), lessThan(0.1));

    final hi = initial.computeLuminance() + 0.05;
    final lo = background.computeLuminance() + 0.05;
    expect(hi / lo, greaterThanOrEqualTo(4.5));
  });
}
