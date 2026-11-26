/// Tests for the building blocks shared by the supervision screens.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/status_progress/status_progress.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_breadcrumb.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_count_pill.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_summary_box.dart';

Widget _host(
  Widget child, {
  ThemeData? theme,
  double textScale = 1,
}) =>
    MaterialApp(
      theme: theme ?? AppTheme.lightTheme,
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: app!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  group('SupervisionCountPill', () {
    testWidgets('shows the number in the accent fill and reads it aloud',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const SupervisionCountPill(count: 6)));

      expect(find.text('6'), findsOneWidget);
      final box = tester.widget<Container>(find.byType(Container).last);
      final accent = SacAccent.of(tester.element(find.byType(Container).last));
      expect((box.decoration! as BoxDecoration).color, accent.color);
      expect(find.bySemanticsLabel('6'), findsOneWidget);
      // A single digit stays a circle at least 24 tall.
      expect(tester.getSize(find.byType(SupervisionCountPill)).height, 24);
      handle.dispose();
    });

    testWidgets('a custom semantic label replaces the number', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(
        const SupervisionCountPill(count: 3, semanticLabel: '3 por validar'),
      ));

      expect(find.bySemanticsLabel('3 por validar'), findsOneWidget);
      handle.dispose();
    });
  });

  group('SupervisionAllClearLabel', () {
    testWidgets('pairs a check icon with the text (not color only)',
        (tester) async {
      await tester.pumpWidget(_host(
        const SupervisionAllClearLabel(label: 'Al día'),
      ));

      expect(find.text('Al día'), findsOneWidget);
      expect(find.byType(HugeIcon), findsOneWidget);
    });
  });

  group('SupervisionStatusChip', () {
    testWidgets('renders icon and text through SacBadge for each tone',
        (tester) async {
      final expected = {
        SacTone.accent: SacBadgeVariant.primary,
        SacTone.success: SacBadgeVariant.secondary,
        SacTone.warning: SacBadgeVariant.accent,
        SacTone.info: SacBadgeVariant.info,
        SacTone.muted: SacBadgeVariant.neutral,
        SacTone.error: SacBadgeVariant.error,
      };
      for (final entry in expected.entries) {
        await tester.pumpWidget(_host(
          SupervisionStatusChip(
            label: 'Aprobada',
            icon: HugeIcons.strokeRoundedTick02,
            tone: entry.key,
          ),
        ));
        final badge = tester.widget<SacBadge>(find.byType(SacBadge));
        expect(badge.variant, entry.value, reason: '${entry.key}');
        expect(badge.label, 'Aprobada');
        expect(badge.icon, isNotNull);
      }
    });
  });

  group('SupervisionSegmentedControl', () {
    const segments = [
      SupervisionSegment(value: 0, label: 'Por validar', count: 3),
      SupervisionSegment(value: 1, label: 'Aprobadas', count: 18),
      SupervisionSegment(value: 2, label: 'Rechazadas', count: 1),
    ];

    testWidgets('reports the tapped segment and marks the selected one',
        (tester) async {
      final handle = tester.ensureSemantics();
      int? picked;
      await tester.pumpWidget(_host(
        SupervisionSegmentedControl<int>(
          segments: segments,
          selected: 0,
          onChanged: (v) => picked = v,
        ),
      ));

      final selected = tester.getSemantics(
        find.bySemanticsLabel('Por validar, 3'),
      );
      expect(selected.flagsCollection.isSelected, Tristate.isTrue);
      expect(selected.flagsCollection.isButton, isTrue);
      final other = tester.getSemantics(find.bySemanticsLabel('Aprobadas, 18'));
      expect(other.flagsCollection.isSelected, Tristate.isFalse);

      await tester.tap(find.textContaining('Aprobadas'));
      expect(picked, 1);
      handle.dispose();
    });

    testWidgets('every option is at least 44 tall', (tester) async {
      await tester.pumpWidget(_host(
        SupervisionSegmentedControl<int>(
          segments: segments,
          selected: 1,
          onChanged: (_) {},
        ),
      ));

      for (final label in ['Por validar', 'Aprobadas', 'Rechazadas']) {
        final box = find.ancestor(
          of: find.textContaining(label),
          matching: find.byType(AnimatedContainer),
        );
        expect(tester.getSize(box).height, greaterThanOrEqualTo(44));
      }
    });

    testWidgets('does not overflow at 320 wide and text scale 2.0',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(
        SupervisionSegmentedControl<int>(
          segments: segments,
          selected: 0,
          onChanged: (_) {},
        ),
        textScale: 2,
      ));

      expect(tester.takeException(), isNull);
    });
  });

  group('SupervisionSummaryBox', () {
    testWidgets('shows label, meta, figure, caption and the legend',
        (tester) async {
      await tester.pumpWidget(_host(
        const SupervisionSummaryBox(
          label: 'Por atender',
          meta: 'límite 12 nov',
          value: '13',
          caption: 'en 3 de 4 colas',
          segments: [
            SacStatusSegment(count: 3, color: Colors.red, label: 'A 3'),
            SacStatusSegment(count: 0, color: Colors.blue, label: 'B 0'),
            SacStatusSegment(count: 4, color: Colors.green, label: 'C 4'),
          ],
        ),
      ));

      expect(find.text('Por atender'), findsOneWidget);
      expect(find.text('límite 12 nov'), findsOneWidget);
      expect(find.textContaining('13  ·  en 3 de 4 colas'), findsOneWidget);
      // Zero segments are not drawn or listed.
      expect(find.textContaining('A 3'), findsOneWidget);
      expect(find.textContaining('B 0'), findsNothing);
      expect(find.textContaining('C 4'), findsOneWidget);
    });

    testWidgets('without segments draws no bar and no meta', (tester) async {
      await tester.pumpWidget(_host(
        const SupervisionSummaryBox(label: 'Informes', value: '83%'),
      ));

      expect(find.byType(SacStatusBar), findsNothing);
      expect(find.text('83%'), findsOneWidget);
    });
  });

  group('SupervisionBreadcrumb', () {
    testWidgets('ancestors are buttons that go back, the current is plain',
        (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(_host(
        SupervisionBreadcrumb(
          crumbs: [
            SupervisionCrumb(
                label: 'Unión Mexicana del Sur', onTap: () => taps++),
            const SupervisionCrumb(label: 'Misión Istmo'),
          ],
        ),
      ));

      final ancestor =
          tester.getSemantics(find.bySemanticsLabel('Unión Mexicana del Sur'));
      expect(ancestor.flagsCollection.isButton, isTrue);
      final current =
          tester.getSemantics(find.bySemanticsLabel('Misión Istmo'));
      expect(current.flagsCollection.isButton, isFalse);
      expect(current.flagsCollection.isSelected, Tristate.isTrue);

      await tester.tap(find.text('Unión Mexicana del Sur'));
      expect(taps, 1);
      await tester.tap(find.text('Misión Istmo'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('the tappable chip keeps a 44 tall hit area', (tester) async {
      await tester.pumpWidget(_host(
        SupervisionBreadcrumb(
          crumbs: [
            SupervisionCrumb(label: 'Unión', onTap: () {}),
            const SupervisionCrumb(label: 'Campo'),
          ],
        ),
      ));

      final hit = find.ancestor(
        of: find.text('Unión'),
        matching: find.byType(ConstrainedBox),
      );
      final heights = [
        for (final e in hit.evaluate())
          (e.renderObject! as RenderBox).size.height,
      ];
      expect(heights.any((h) => h >= 44), isTrue);
    });

    testWidgets('wraps long paths without overflow at 320 and scale 2.0',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(
        SupervisionBreadcrumb(
          crumbs: [
            SupervisionCrumb(label: 'Unión Mexicana del Sur', onTap: () {}),
            SupervisionCrumb(label: 'Asociación del Golfo', onTap: () {}),
            const SupervisionCrumb(label: 'Distrito Centro'),
          ],
        ),
        textScale: 2,
      ));

      expect(tester.takeException(), isNull);
    });
  });
}
