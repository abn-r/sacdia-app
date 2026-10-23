/// Tests for the redesigned CoordinatorHubView (coordination tab root).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_stat_tile.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_club.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/report_compliance.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_reports_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/coordinator_hub_view.dart';

import '../../coordinator_test_harness.dart';

const _scope = CoordinatorScope(
  isCoordinator: true,
  clubSectionIds: [1, 2, 3],
  sections: [
    CoordinatorSectionScope(
      clubSectionId: 1,
      clubTypeId: 1,
      clubTypeName: 'Conquistadores',
      clubId: 10,
      clubName: 'Club Alfa',
      districtName: 'Distrito Norte',
      localFieldName: 'Campo Local 1',
    ),
    CoordinatorSectionScope(
      clubSectionId: 2,
      clubTypeId: 2,
      clubTypeName: 'Aventureros',
      clubId: 10,
      clubName: 'Club Alfa',
      districtName: 'Distrito Norte',
      localFieldName: 'Campo Local 1',
    ),
    CoordinatorSectionScope(
      clubSectionId: 3,
      clubTypeId: 1,
      clubTypeName: 'Conquistadores',
      clubId: 11,
      clubName: 'Club Beta',
      districtName: 'Distrito Norte',
      localFieldName: 'Campo Local 1',
    ),
  ],
);

const _sla = SlaDashboard(
  investiture: SlaStat(pending: 35, avgDays: 0, overdue: 4),
  evidence: SlaStat(pending: 6, avgDays: 2.5, overdue: 2),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 1),
  throughput: [],
  pipeline: [],
);

const _slaClear = SlaDashboard(
  investiture: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  evidence: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  throughput: [],
  pipeline: [],
);

EvidenceReviewItem _item(String id, String name, int daysAgo) =>
    EvidenceReviewItem(
      id: id,
      type: EvidenceReviewType.honor,
      status: EvidenceReviewStatus.pending,
      memberName: name,
      context: 'Especialidad $id',
      submittedAt: DateTime.now().subtract(Duration(days: daysAgo)),
      fileCount: 1,
    );

// Deliberately unsorted: the hub must show the three OLDEST first.
final _items = [
  _item('a', 'Ana Nueva', 1),
  _item('b', 'Beto Antiguo', 20),
  _item('c', 'Carla Media', 9),
  _item('d', 'Diego Viejo', 14),
];

const _clubs = [
  CoordinatorClub(
    id: 10,
    name: 'Club Alfa',
    localFieldId: 1,
    districtName: 'Distrito Norte',
    sections: [
      CoordinatorSectionScope(
        clubSectionId: 1,
        clubTypeId: 1,
        clubTypeName: 'Conquistadores',
      ),
    ],
  ),
  CoordinatorClub(id: 11, name: 'Club Beta', localFieldId: 1),
  CoordinatorClub(id: 12, name: 'Club Gamma', localFieldId: 1),
  CoordinatorClub(id: 13, name: 'Club Delta', localFieldId: 1),
];

final _compliance = ReportCompliance(
  asOf: DateTime.utc(2026, 10, 22),
  ecclesiasticalYearId: 7,
  clubCount: 2,
  monthly:
      const ReportCounts(expected: 13, submitted: 10, pending: 1, overdue: 2),
  quarterly: const ReportCounts(expected: 3, submitted: 2, overdue: 1),
  annual: ReportCounts.zero,
);

Future<void> _pumpHub(
  WidgetTester tester, {
  FutureOr<CoordinatorScope> Function()? scope,
  FutureOr<SlaDashboard> Function()? sla,
  FutureOr<List<EvidenceReviewItem>> Function()? pending,
  int? pendingTotal,
  FutureOr<List<CoordinatorClub>> Function()? clubs,
  FutureOr<ReportCompliance> Function()? reports,
}) async {
  useTallSurface(tester);

  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => const CoordinatorHubView()),
      GoRoute(
        path: '/coordinator/evidence-review',
        builder: (_, __) => const Text('page:evidence-list'),
      ),
      GoRoute(
        path: '/coordinator/evidence-review/:type/:id',
        builder: (_, state) => Text(
          'page:evidence-detail:${state.pathParameters['type']}:'
          '${state.pathParameters['id']}',
        ),
      ),
      GoRoute(
        path: '/coordinator/sla',
        builder: (_, __) => const Text('page:sla'),
      ),
      GoRoute(
        path: '/coordinator/clubs',
        builder: (_, __) => const Text('page:clubs'),
      ),
      GoRoute(
        path: '/coordinator/reports',
        builder: (_, __) => const Text('page:reports'),
      ),
      GoRoute(
        path: '/club/:clubId',
        builder: (_, state) =>
            Text('page:club:${state.pathParameters['clubId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        coordinatorScopeProvider
            .overrideWith((ref) async => (scope ?? () => _scope)()),
        slaDashboardProvider.overrideWith((ref) async => (sla ?? () => _sla)()),
        pendingEvidenceOverride(
          (type, page) async => singlePage(
            await (pending ?? () => _items)(),
            total: pendingTotal,
          ),
        ),
        coordinatorClubsRawProvider
            .overrideWith((ref) async => (clubs ?? () => _clubs)()),
        reportComplianceProvider.overrideWith(
          (ref, query) async => (reports ?? () => _compliance)(),
        ),
      ],
      child: localized((context) => localizedRouterApp(context, router)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('scope subtitle', () {
    test('counts distinct clubs and names the single district', () {
      expect(
        coordinatorScopeSubtitle(_scope),
        'coordinator.hub.scope.clubs_other · Distrito Norte',
      );
    });

    test('summarizes the district count when there are several', () {
      const scope = CoordinatorScope(
        isCoordinator: true,
        clubSectionIds: [1, 2],
        sections: [
          CoordinatorSectionScope(
            clubSectionId: 1,
            clubTypeId: 1,
            clubId: 1,
            districtName: 'Norte',
          ),
          CoordinatorSectionScope(
            clubSectionId: 2,
            clubTypeId: 1,
            clubId: 1,
            districtName: 'Sur',
          ),
        ],
      );
      expect(
        coordinatorScopeSubtitle(scope),
        'coordinator.hub.scope.clubs_one · '
        'coordinator.hub.scope.districts_other',
      );
    });

    test('falls back to the local field, then to the clubs list', () {
      const scope = CoordinatorScope(
        isCoordinator: true,
        clubSectionIds: [1],
        sections: [
          CoordinatorSectionScope(
            clubSectionId: 1,
            clubTypeId: 1,
            localFieldName: 'Campo Local 1',
          ),
        ],
      );
      expect(
        coordinatorScopeSubtitle(scope, clubsFallback: _clubs),
        'coordinator.hub.scope.clubs_other · Campo Local 1',
      );
    });

    test('is null without assigned sections', () {
      expect(
        coordinatorScopeSubtitle(const CoordinatorScope(isCoordinator: true)),
        isNull,
      );
    });
  });

  group('data', () {
    testWidgets('uses a frosted top bar with no gradient app bar',
        (tester) async {
      await _pumpHub(tester);

      expect(find.byType(SliverAppBar), findsNothing);
      final bar = tester.widget<SacTopBar>(find.byType(SacTopBar));
      expect(bar.frosted, isTrue);
      expect(bar.title, 'Coordinación');
      expect(bar.subtitle, contains('Distrito Norte'));
      // Tab root: no back button.
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('review section shows the count, badges and the 3 oldest',
        (tester) async {
      await _pumpHub(tester);

      expect(find.text('Por revisar'), findsOneWidget);
      expect(find.text('Ver todas'), findsOneWidget);
      expect(find.text('evidencias por revisar'), findsOneWidget);
      expect(find.text('2 vencidas'), findsOneWidget);
      expect(find.text('Promedio 2,5 d'), findsOneWidget);

      // Oldest first: 20d, 14d, 9d. The 1-day-old item is left out.
      expect(find.text('Beto Antiguo'), findsOneWidget);
      expect(find.text('Diego Viejo'), findsOneWidget);
      expect(find.text('Carla Media'), findsOneWidget);
      expect(find.text('Ana Nueva'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Beto Antiguo')).dy,
        lessThan(tester.getTopLeft(find.text('Diego Viejo')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Diego Viejo')).dy,
        lessThan(tester.getTopLeft(find.text('Carla Media')).dy),
      );
    });

    testWidgets('the review count is the server total of the queue',
        (tester) async {
      // 4 loaded on the first page, 57 waiting on the server; the SLA
      // dashboard (6) only feeds the response-time tiles.
      await _pumpHub(tester, pendingTotal: 57);

      final summary = find.ancestor(
        of: find.text('evidencias por revisar'),
        matching: find.byType(SacCard),
      );
      expect(
        find.descendant(of: summary, matching: find.text('57')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: summary, matching: find.text('6')),
        findsNothing,
      );
    });

    testWidgets('response time section shows three stat tiles', (tester) async {
      await _pumpHub(tester);

      expect(find.text('Tiempo de respuesta'), findsOneWidget);
      // Three response-time tiles; the other three belong to the reports
      // summary further down.
      expect(find.byType(SacStatTile), findsNWidgets(6));
      final slaTiles = tester
          .widgetList<SacStatTile>(find.byType(SacStatTile))
          .take(3)
          .map((t) => t.label);
      expect(slaTiles, ['Pendientes', 'Promedio (días)', 'Vencidas']);
      expect(find.text('Promedio (días)'), findsOneWidget);
      expect(find.text('Vencidas'), findsOneWidget);
      expect(find.text('6'), findsWidgets);
      expect(find.text('2,5'), findsWidgets);
      // Investiture/camporee overdue are not added (would read 7).
      expect(find.text('7'), findsNothing);
      expect(find.text('35'), findsNothing);
    });

    testWidgets('clubs section previews the first 3 clubs and links to all',
        (tester) async {
      await _pumpHub(tester);

      expect(find.text('Mis clubes'), findsOneWidget);
      expect(find.text('Ver 4'), findsOneWidget);
      expect(find.text('Club Alfa'), findsOneWidget);
      expect(find.text('Club Beta'), findsOneWidget);
      expect(find.text('Club Gamma'), findsOneWidget);
      expect(find.text('Club Delta'), findsNothing);
      expect(find.text('Distrito Norte'), findsOneWidget);
      expect(find.text('Conquistadores'), findsOneWidget);
    });

    testWidgets('reports section summarizes compliance and opens the reports',
        (tester) async {
      await _pumpHub(tester);

      expect(find.text('Reportes'), findsOneWidget);
      expect(find.text('Próximamente'), findsNothing);
      final tiles = tester
          .widgetList<SacStatTile>(find.byType(SacStatTile))
          .where((t) => t.label == 'Enviados' || t.label == 'Vencidos')
          .toList();
      expect(tiles.map((t) => t.value), [12, 3]);

      await tester.tap(find.text('Ver informes'));
      await tester.pumpAndSettle();
      expect(find.text('page:reports'), findsOneWidget);
    });

    testWidgets('reports section without access shows a muted note',
        (tester) async {
      await _pumpHub(
        tester,
        reports: () =>
            throw const CoordinatorLoadException('403', isForbidden: true),
      );

      expect(
        find.text('Tu rol no tiene acceso a los informes de los clubes.'),
        findsOneWidget,
      );
      expect(find.text('Ver informes'), findsNothing);
    });

    testWidgets('shows the all-clear row instead of a preview when 0 pending',
        (tester) async {
      await _pumpHub(
        tester,
        sla: () => _slaClear,
        pending: () => const [],
      );

      expect(find.text('Todo al día'), findsOneWidget);
      expect(find.text('Las más antiguas primero'), findsNothing);
      expect(find.text('evidencias por revisar'), findsNothing);
      expect(find.text('Beto Antiguo'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('"see all" opens the evidence list', (tester) async {
      await _pumpHub(tester);
      await tester.tap(find.text('Ver todas'));
      await tester.pumpAndSettle();
      expect(find.text('page:evidence-list'), findsOneWidget);
    });

    testWidgets('summary card opens the evidence list', (tester) async {
      await _pumpHub(tester);
      await tester.tap(find.text('evidencias por revisar'));
      await tester.pumpAndSettle();
      expect(find.text('page:evidence-list'), findsOneWidget);
    });

    testWidgets('a preview row opens the evidence detail', (tester) async {
      await _pumpHub(tester);
      await tester.tap(find.text('Beto Antiguo'));
      await tester.pumpAndSettle();
      expect(find.text('page:evidence-detail:honor:b'), findsOneWidget);
    });

    testWidgets('response time tiles and link open the SLA dashboard',
        (tester) async {
      await _pumpHub(tester);
      await tester.tap(find.text('Vencidas'));
      await tester.pumpAndSettle();
      expect(find.text('page:sla'), findsOneWidget);
    });

    testWidgets('clubs link opens the full list and a row opens the club',
        (tester) async {
      await _pumpHub(tester);
      await tester.tap(find.text('Club Beta'));
      await tester.pumpAndSettle();
      expect(find.text('page:club:11'), findsOneWidget);
    });

    testWidgets('"view N" opens the clubs list', (tester) async {
      await _pumpHub(tester);
      await tester.tap(find.text('Ver 4'));
      await tester.pumpAndSettle();
      expect(find.text('page:clubs'), findsOneWidget);
    });
  });

  group('loading', () {
    testWidgets('shows skeletons shaped like the real layout', (tester) async {
      final never = Completer<CoordinatorScope>();
      useTallSurface(tester);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            coordinatorScopeProvider.overrideWith((ref) => never.future),
          ],
          child: localized(
            (context) => localizedApp(context, const CoordinatorHubView()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      // 3 skeleton stat tiles, no real labels, no previews, no error/empty.
      expect(find.byType(SacStatTile), findsNWidgets(3));
      expect(find.text('Pendientes'), findsNothing);
      expect(find.text('Por revisar'), findsOneWidget);
      expect(find.text('Tiempo de respuesta'), findsOneWidget);
      expect(find.text('Mis clubes'), findsOneWidget);
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.byType(SacEmptyState), findsNothing);

      // Resolve and dispose so no provider timer outlives the test.
      never.complete(_scope);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('empty and error states', () {
    testWidgets('a non-coordinator scope shows the empty state',
        (tester) async {
      await _pumpHub(
        tester,
        scope: () => const CoordinatorScope(isCoordinator: false),
      );

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('Aún no tienes secciones asignadas'), findsOneWidget);
      expect(find.text('Por revisar'), findsNothing);
    });

    testWidgets('a coordinator without sections shows the empty state',
        (tester) async {
      await _pumpHub(
        tester,
        scope: () => const CoordinatorScope(isCoordinator: true),
      );

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.textContaining('Cuando te asignen clubes'), findsOneWidget);
    });

    testWidgets('a 403 on the scope shows the forbidden state', (tester) async {
      await _pumpHub(
        tester,
        scope: () => throw const CoordinatorLoadException(
          'No tienes permiso para realizar esta acción',
          isForbidden: true,
        ),
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      final icon = tester.widget<HugeIcon>(
        find.descendant(
          of: find.byType(SacErrorState),
          matching: find.byType(HugeIcon),
        ),
      );
      expect(icon.icon, HugeIcons.strokeRoundedLockKey);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('a scope failure shows a retryable error, not raw text',
        (tester) async {
      await _pumpHub(tester, scope: () => throw Exception('boom: 500'));

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('No pudimos cargar tu panel de coordinación'),
          findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
    });

    testWidgets(
        'a failing section shows an inline retry while the others still render',
        (tester) async {
      var slaCalls = 0;
      await _pumpHub(
        tester,
        sla: () {
          slaCalls++;
          throw Exception('sla down');
        },
      );

      // Review summary + response-time section each show their own error.
      expect(find.text('No pudimos cargar esta sección.'), findsNWidgets(2));
      expect(find.textContaining('sla down'), findsNothing);
      // Clubs and evidence previews are unaffected.
      expect(find.text('Club Alfa'), findsOneWidget);
      expect(find.text('Beto Antiguo'), findsOneWidget);

      final before = slaCalls;
      await tester.tap(find.text('Reintentar').first);
      await tester.pumpAndSettle();
      expect(slaCalls, greaterThan(before));
    });
  });
}
