/// Tests for the redesigned SLADashboardView ("Tiempo de respuesta").
library;

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/core/widgets/sac_stat_tile.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/sla_dashboard_view.dart';

import '../../coordinator_test_harness.dart';

const _stat = SlaStat(pending: 6, avgDays: 2.5, overdue: 3);
const _noStat = SlaStat(pending: 0, avgDays: 0, overdue: 0);

const _full = SlaDashboard(
  investiture: SlaStat(pending: 35, avgDays: 4, overdue: 2),
  evidence: _stat,
  camporee: _noStat,
  throughput: [
    ThroughputPoint(week: '2026-W39', approved: 4, rejected: 1),
    ThroughputPoint(week: '2026-W40', approved: 5, rejected: 2),
  ],
  pipeline: [
    PipelineStage(stage: 'Enviado para validación', count: 8),
    PipelineStage(stage: 'En revisión', count: 2),
  ],
);

SlaDashboard _with({
  SlaStat evidence = _stat,
  List<ThroughputPoint> throughput = const [],
  List<PipelineStage> pipeline = const [],
}) =>
    SlaDashboard(
      investiture: const SlaStat(pending: 35, avgDays: 4, overdue: 2),
      evidence: evidence,
      camporee: _noStat,
      throughput: throughput,
      pipeline: pipeline,
    );

Future<void> _pumpSla(
  WidgetTester tester,
  FutureOr<SlaDashboard> Function() sla,
) async {
  useTallSurface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        slaDashboardProvider.overrideWith((ref) async => sla()),
      ],
      child: localized(
        (context) => localizedApp(context, const SLADashboardView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Disposes the view so its 60 s auto-refresh timer is cancelled.
Future<void> _dispose(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('data', () {
    testWidgets('uses a frosted top bar and shows the three evidence KPIs',
        (tester) async {
      await _pumpSla(tester, () => _full);

      final bar = tester.widget<SacTopBar>(find.byType(SacTopBar));
      expect(bar.frosted, isTrue);
      expect(bar.title, 'Tiempo de respuesta');

      expect(find.byType(SacStatTile), findsNWidgets(3));
      expect(find.text('Pendientes'), findsOneWidget);
      expect(find.text('Promedio (días)'), findsOneWidget);
      expect(find.text('Vencidas'), findsOneWidget);
      Finder inTile(int index, String text) => find.descendant(
            of: find.byType(SacStatTile).at(index),
            matching: find.text(text),
          );
      expect(inTile(0, '6'), findsOneWidget);
      expect(inTile(1, '2,5'), findsOneWidget);
      expect(inTile(2, '3'), findsOneWidget);
      // Investiture figures never leak into the evidence KPIs.
      expect(find.text('35'), findsNothing);

      await _dispose(tester);
    });

    testWidgets('plots approved vs rejected per week with a text legend',
        (tester) async {
      await _pumpSla(tester, () => _full);

      expect(find.text('Revisiones por semana'), findsOneWidget);
      expect(find.byType(BarChart), findsOneWidget);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(chart.data.barGroups, hasLength(2));
      expect(chart.data.barGroups.first.barRods, hasLength(2));
      // Legend carries labels and totals, not just colors.
      expect(find.text('Aprobadas · 9'), findsOneWidget);
      expect(find.text('Rechazadas · 3'), findsOneWidget);
      // Week labels on the x axis.
      expect(find.text('S39'), findsOneWidget);
      expect(find.text('S40'), findsOneWidget);

      await _dispose(tester);
    });

    testWidgets('hides the chart and shows a note with fewer than 2 weeks',
        (tester) async {
      await _pumpSla(
        tester,
        () => _with(
          throughput: const [
            ThroughputPoint(week: '2026-W40', approved: 5, rejected: 1),
          ],
        ),
      );

      expect(find.byType(BarChart), findsNothing);
      expect(
        find.text(
          'Aún no hay suficientes semanas con revisiones para mostrar la '
          'tendencia.',
        ),
        findsOneWidget,
      );

      await _dispose(tester);
    });

    testWidgets('never renders the retired investiture pipeline',
        (tester) async {
      // `_full` still carries pipeline stages: the view must ignore them.
      await _pumpSla(tester, () => _full);

      expect(find.text('Etapas de revisión'), findsNothing);
      expect(find.text('Enviado para validación'), findsNothing);
      expect(find.text('En revisión'), findsNothing);
      expect(find.byType(SacProgressBar), findsNothing);

      await _dispose(tester);
    });
  });

  group('loading', () {
    testWidgets('renders skeleton tiles and a chart-card placeholder',
        (tester) async {
      final never = Completer<SlaDashboard>();
      useTallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            slaDashboardProvider.overrideWith((ref) => never.future),
          ],
          child: localized(
            (context) => localizedApp(context, const SLADashboardView()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SacStatTile), findsNWidgets(3));
      expect(find.text('Pendientes'), findsNothing);
      expect(find.byType(BarChart), findsNothing);
      expect(find.byType(SacErrorState), findsNothing);

      never.complete(_full);
      await _dispose(tester);
    });
  });

  group('empty and error states', () {
    testWidgets('all zeros and no series show the empty state', (tester) async {
      await _pumpSla(tester, () => _with(evidence: _noStat));

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('Aún no hay datos'), findsOneWidget);
      expect(find.byType(SacStatTile), findsNothing);

      await _dispose(tester);
    });

    testWidgets('a load failure shows a localized retryable error',
        (tester) async {
      var calls = 0;
      await _pumpSla(tester, () {
        calls++;
        throw Exception('Exception: connection reset (500)');
      });

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(
        find.text('No pudimos cargar el tiempo de respuesta'),
        findsOneWidget,
      );
      // Raw exception text is never shown.
      expect(find.textContaining('connection reset'), findsNothing);

      final before = calls;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));

      await _dispose(tester);
    });

    testWidgets('a 403 shows the access-restricted state without retry',
        (tester) async {
      await _pumpSla(
        tester,
        () => throw const CoordinatorLoadException(
          'No tienes permiso para realizar esta acción',
          isForbidden: true,
        ),
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('Acceso restringido'), findsOneWidget);
      final icon = tester.widget<HugeIcon>(
        find.descendant(
          of: find.byType(SacErrorState),
          matching: find.byType(HugeIcon),
        ),
      );
      expect(icon.icon, HugeIcons.strokeRoundedLockKey);
      expect(find.text('Reintentar'), findsNothing);

      await _dispose(tester);
    });
  });

  group('slaHasData', () {
    test('ignores camporee and investiture figures', () {
      expect(
        slaHasData(
          const SlaDashboard(
            investiture: SlaStat(pending: 9, avgDays: 9, overdue: 9),
            evidence: _noStat,
            camporee: SlaStat(pending: 4, avgDays: 1, overdue: 1),
            throughput: [],
            pipeline: [],
          ),
        ),
        isFalse,
      );
    });

    test('is true with any evidence figure or weekly activity', () {
      expect(slaHasData(_with(evidence: _noStat)), isFalse);
      expect(
        slaHasData(
          _with(
            evidence: const SlaStat(pending: 0, avgDays: 0, overdue: 1),
          ),
        ),
        isTrue,
      );
      expect(
        slaHasData(
          _with(
            evidence: _noStat,
            throughput: const [
              ThroughputPoint(week: 'W1', approved: 1, rejected: 0),
            ],
          ),
        ),
        isTrue,
      );
    });

    test('ignores pipeline stages, which are not shown', () {
      expect(
        slaHasData(
          _with(
            evidence: _noStat,
            pipeline: const [PipelineStage(stage: 'x', count: 1)],
          ),
        ),
        isFalse,
      );
    });
  });
}
