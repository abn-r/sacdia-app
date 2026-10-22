import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_stat_tile.dart';

/// Reduced motion so [AnimatedCounter] shows its final value immediately.
Widget _host(Widget child, {ThemeData? theme}) => MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('shows the value and label inside a SacCard', (tester) async {
    await tester.pumpWidget(
      _host(
        const SacStatTile(
          icon: HugeIcons.strokeRoundedFolder01,
          value: 7,
          label: 'Pendientes',
        ),
      ),
    );

    expect(find.byType(SacCard), findsOneWidget);
    expect(find.byType(AnimatedCounter), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('Pendientes'), findsOneWidget);
    expect(find.byType(HugeIcon), findsOneWidget);
  });

  testWidgets('formats decimals through the counter', (tester) async {
    await tester.pumpWidget(
      _host(
        const SacStatTile(
          icon: HugeIcons.strokeRoundedClock01,
          value: 2.5,
          decimals: 1,
          label: 'Promedio',
        ),
      ),
    );

    expect(find.text('2.5'), findsOneWidget);
  });

  testWidgets('tone drives the icon tint from the sac tokens', (tester) async {
    Color iconColor() => tester.widget<HugeIcon>(find.byType(HugeIcon)).color!;

    await tester.pumpWidget(
      _host(
        const SacStatTile(
          icon: HugeIcons.strokeRoundedAlert02,
          value: 3,
          label: 'Vencidas',
          tone: SacStatTone.error,
        ),
      ),
    );
    final context = tester.element(find.byType(SacStatTile));
    expect(iconColor(), context.sac.error);

    await tester.pumpWidget(
      _host(
        const SacStatTile(
          icon: HugeIcons.strokeRoundedAlert02,
          value: 3,
          label: 'Vencidas',
          tone: SacStatTone.success,
        ),
      ),
    );
    expect(iconColor(), context.sac.success);

    await tester.pumpWidget(
      _host(
        const SacStatTile(
          icon: HugeIcons.strokeRoundedAlert02,
          value: 3,
          label: 'Vencidas',
        ),
      ),
    );
    expect(iconColor(), context.sac.textSecondary);
  });

  testWidgets('onTap fires when the tile is tapped', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SacStatTile(
          icon: HugeIcons.strokeRoundedFolder01,
          value: 1,
          label: 'Pendientes',
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('Pendientes'));
    expect(taps, 1);
  });

  testWidgets('skeleton renders the card layout without text or counter',
      (tester) async {
    await tester.pumpWidget(_host(const SacStatTile.skeleton()));

    expect(find.byType(SacCard), findsOneWidget);
    expect(find.byType(AnimatedCounter), findsNothing);
    expect(find.byType(Text), findsNothing);
    expect(find.byType(HugeIcon), findsNothing);
  });

  testWidgets('works in dark theme', (tester) async {
    await tester.pumpWidget(
      _host(
        const SacStatTile(
          icon: HugeIcons.strokeRoundedFolder01,
          value: 4,
          label: 'Pendientes',
          tone: SacStatTone.accent,
        ),
        theme: AppTheme.darkTheme,
      ),
    );

    expect(find.text('4'), findsOneWidget);
  });
}
