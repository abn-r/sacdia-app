/// Tests for the widgets shared by the «Por decidir» screens: the quote, the
/// stacked actions, the row age and the «de → a» box.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_move_box.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_actions.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_quote.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_row_parts.dart';

Widget sacHarness(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  group('SupervisionQuote', () {
    testWidgets('shows the label and the text, read as one node', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(sacHarness(
        const SupervisionQuote(
          label: 'Motivo',
          text: 'Falta la firma',
          tone: SacTone.error,
        ),
      ));

      expect(find.text('Motivo'), findsOneWidget);
      expect(find.text('Falta la firma'), findsOneWidget);
      expect(find.bySemanticsLabel('Motivo. Falta la firma'), findsOneWidget);
      handle.dispose();
    });
  });

  group('SupervisionStackedActions', () {
    Widget actions({
      bool loading = false,
      bool destructive = false,
      VoidCallback? onPrimary,
      VoidCallback? onSecondary,
    }) =>
        sacHarness(
          SupervisionStackedActions(
            primaryLabel: 'Aprobar',
            primaryIcon: HugeIcons.strokeRoundedTick02,
            onPrimary: onPrimary ?? () {},
            secondaryLabel: 'Rechazar',
            secondaryIcon: HugeIcons.strokeRoundedCancel01,
            onSecondary: onSecondary ?? () {},
            isLoading: loading,
            primaryDestructive: destructive,
          ),
        );

    testWidgets('primary on top, secondary under it, both fire', (
      tester,
    ) async {
      var primary = 0;
      var secondary = 0;
      await tester.pumpWidget(actions(
        onPrimary: () => primary++,
        onSecondary: () => secondary++,
      ));

      final top = tester.getRect(find.widgetWithText(SacButton, 'Aprobar'));
      final bottom = tester.getRect(find.widgetWithText(SacButton, 'Rechazar'));
      expect(bottom.top, greaterThanOrEqualTo(top.bottom));

      await tester.tap(find.widgetWithText(SacButton, 'Aprobar'));
      await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
      expect(primary, 1);
      expect(secondary, 1);
    });

    testWidgets('loading disables the pair and spins the primary', (
      tester,
    ) async {
      await tester.pumpWidget(actions(loading: true));
      await tester.pump();

      final primary =
          tester.widget<SacButton>(find.widgetWithText(SacButton, 'Aprobar'));
      final secondary =
          tester.widget<SacButton>(find.widgetWithText(SacButton, 'Rechazar'));
      expect(primary.isLoading, isTrue);
      expect(secondary.isEnabled, isFalse);
    });

    testWidgets('a destructive primary is the red variant', (tester) async {
      await tester.pumpWidget(actions(destructive: true));

      expect(
        tester
            .widget<SacButton>(find.widgetWithText(SacButton, 'Aprobar'))
            .variant,
        SacButtonVariant.destructive,
      );
    });

    testWidgets('a long secondary label wraps at 2x text without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, app) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
          ),
          child: app!,
        ),
        home: Scaffold(
          body: SupervisionStackedActions(
            primaryLabel: 'Ok',
            onPrimary: () {},
            secondaryLabel: 'Rechazar solicitud de traslado',
            onSecondary: () {},
          ),
        ),
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('SupervisionRowAge', () {
    testWidgets(
        'relative by default, the day when absolute, nothing without '
        'a date', (tester) async {
      await tester.pumpWidget(sacHarness(
        Column(
          children: [
            SupervisionRowAge(when: DateTime(2026, 3, 12), absolute: true),
            const SupervisionRowAge(when: null),
          ],
        ),
      ));

      expect(find.text('12 mar'), findsOneWidget);
      expect(find.byType(Text), findsOneWidget);
    });
  });

  group('SacMoveBox', () {
    testWidgets('origin, strip and destination; no origin: no strip', (
      tester,
    ) async {
      await tester.pumpWidget(sacHarness(
        const SacMoveBox(
          connector: 'Cambio a',
          fromLeading: SizedBox(width: 40, height: 40),
          fromTitle: 'Orión',
          fromSubtitle: 'Conquistadores',
          toLeading: SizedBox(width: 40, height: 40),
          toTitle: 'Vega',
          toSubtitle: 'Aventureros',
        ),
      ));
      expect(find.text('Orión'), findsOneWidget);
      expect(find.text('CAMBIO A'), findsOneWidget);
      expect(find.text('Vega'), findsOneWidget);

      await tester.pumpWidget(sacHarness(
        const SacMoveBox(
          connector: 'Cambio a',
          toLeading: SizedBox(width: 40, height: 40),
          toTitle: 'Vega',
        ),
      ));
      expect(find.text('CAMBIO A'), findsNothing);
      expect(find.text('Vega'), findsOneWidget);
    });
  });
}
