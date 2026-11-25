/// Widget tests for the territorial operations dashboard.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_operations.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_operations_view.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_plain_row.dart';

import 'supervision_territory_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _union = SupervisionTerritoryLevel.union;
const _localField = SupervisionTerritoryLevel.localField;
const _club = SupervisionTerritoryLevel.club;

Future<FakeOperationsRepo> _pump(
  WidgetTester tester, {
  FakeOperationsRepo? repo,
  SupervisionOperationsQuery query = const SupervisionOperationsQuery(),
  List<String> capabilities = const [kSupervisionAppView],
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeOperationsRepo();
  await pumpTerritoryApp(
    tester,
    home: SupervisionOperationsView(query: query),
    opsRepo: fake,
    capabilities: capabilities,
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

FakeOperationsRepo _repoWith(SupervisionOperationsDashboard d) =>
    FakeOperationsRepo()..onDashboard = (_) async => Right(d);

Finder _row(String title) => find.widgetWithText(SupervisionPlainRow, title);

bool _isTappable(WidgetTester tester, String title) => find
    .descendant(of: _row(title), matching: find.byType(SacInkWell))
    .evaluate()
    .isNotEmpty;

void main() {
  setUpAll(initSupervisionViewTests);

  group('load states', () {
    testWidgets('shows the skeleton, then the content', (tester) async {
      final gate = Completer<SupervisionOperationsDashboard>();
      final repo = FakeOperationsRepo()
        ..onDashboard = (_) async => Right(await gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('INDICADORES'), findsNothing);

      gate.complete(dashboard());
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('INDICADORES'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('shows the error state and retry reloads the content', (
      tester,
    ) async {
      final repo = FakeOperationsRepo();
      repo.onDashboard = (_) async => repo.queries.length == 1
          ? const Left(kTerritoryBoom)
          : Right(dashboard());
      await _pump(tester, repo: repo);

      expect(
          find.text('No se pudieron cargar los indicadores'), findsOneWidget);
      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('INDICADORES'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.queries, hasLength(2));
      expect(find.text('No se pudieron cargar los indicadores'), findsNothing);
      expect(find.text('INDICADORES'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = FakeOperationsRepo()
        ..onDashboard = (_) async => const Left(kTerritoryForbidden);
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudieron cargar los indicadores'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('shows the empty state when there are no clubs or children', (
      tester,
    ) async {
      final repo = _repoWith(
        dashboard(
            summary: metrics(
                clubsTotal: 0, operationalClubs: 0, nonOperationalClubs: 0)),
      );
      await _pump(tester, repo: repo);

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('Sin clubes en este territorio'), findsOneWidget);
      expect(find.text('INDICADORES'), findsNothing);
    });

    testWidgets('no clubs but with children still shows the dashboard', (
      tester,
    ) async {
      final repo = _repoWith(
        dashboard(
          summary: metrics(clubsTotal: 0),
          children: [opsChild(5, 'Campo A', _localField)],
        ),
      );
      await _pump(tester, repo: repo);

      expect(find.byType(SacEmptyState), findsNothing);
      expect(find.text('Campo A'), findsOneWidget);
    });

    testWidgets('a failed pull-to-refresh keeps the old dashboard', (
      tester,
    ) async {
      final repo = FakeOperationsRepo();
      repo.onDashboard = (_) async => repo.queries.length == 1
          ? Right(dashboard(scopeName: 'Unión Norte'))
          : const Left(kTerritoryBoom);
      await _pump(tester, repo: repo);
      expect(find.text('INDICADORES'), findsOneWidget);

      // The same callback a pull gesture runs.
      final refreshing = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refreshing;
      await tester.pumpAndSettle();

      expect(repo.queries.length, greaterThanOrEqualTo(2));
      expect(find.text('INDICADORES'), findsOneWidget);
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.text('Unión Norte'), findsOneWidget);
    });
  });

  group('top bar and scope', () {
    testWidgets('own scope: title «Operación», subtitle is the scope name', (
      tester,
    ) async {
      await _pump(tester, repo: _repoWith(dashboard(scopeName: 'Unión Norte')));

      expect(find.text('Operación'), findsOneWidget);
      expect(find.text('Unión Norte'), findsOneWidget);
    });

    testWidgets('own scope does not show the parents line', (tester) async {
      final d = dashboard(
        scopeName: 'Unión Norte',
        path: const [
          SupervisionScopeNode(
            level: SupervisionTerritoryLevel.division,
            id: 1,
            name: 'División Sur',
          ),
          SupervisionScopeNode(level: _union, id: 1, name: 'Unión Norte'),
        ],
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.textContaining('›'), findsNothing);
    });

    testWidgets(
        'drilled scope: title is the scope, subtitle the level, parents line '
        'without the scope', (tester) async {
      final d = dashboard(
        level: _localField,
        scopeId: 3,
        scopeName: 'Campo Central',
        path: const [
          SupervisionScopeNode(
            level: SupervisionTerritoryLevel.division,
            id: 1,
            name: 'División Sur',
          ),
          SupervisionScopeNode(level: _union, id: 2, name: 'Unión Norte'),
          SupervisionScopeNode(
              level: _localField, id: 3, name: 'Campo Central'),
        ],
      );
      await _pump(
        tester,
        repo: _repoWith(d),
        query: const SupervisionOperationsQuery(localFieldId: 3),
      );

      expect(find.text('Campo Central'), findsOneWidget);
      expect(find.text('Operación'), findsNothing);
      expect(find.text('Campo local'), findsOneWidget);
      expect(find.text('División Sur › Unión Norte'), findsOneWidget);
    });

    testWidgets('drilled scope without parents shows no path line', (
      tester,
    ) async {
      final d = dashboard(
        scopeName: 'Unión Norte',
        path: const [
          SupervisionScopeNode(level: _union, id: 1, name: 'Unión Norte'),
        ],
      );
      await _pump(
        tester,
        repo: _repoWith(d),
        query: const SupervisionOperationsQuery(unionId: 1),
      );

      expect(find.textContaining('›'), findsNothing);
      expect(find.text('Unión'), findsOneWidget);
    });

    testWidgets('requests the dashboard with the given query', (tester) async {
      final repo = await _pump(
        tester,
        query: const SupervisionOperationsQuery(unionId: 9),
      );

      expect(repo.queries, [const SupervisionOperationsQuery(unionId: 9)]);
    });
  });

  group('indicators', () {
    testWidgets('reports row: caption with month, coverage as value', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Informes del mes'), findsOneWidget);
      expect(find.text('9 de 12 secciones · octubre'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
    });

    testWidgets('no reporting month: «Aún no hay un mes cerrado» and a dash', (
      tester,
    ) async {
      final d = dashboard(
        period: reportingPeriod(reportYear: null, reportMonth: null),
        summary: metrics(reportsCoveragePct: 75),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Aún no hay un mes cerrado'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.text('75%'), findsNothing);
    });

    testWidgets('no reports expected in the month says so with the month', (
      tester,
    ) async {
      final d = dashboard(
        summary: metrics(
          reportsExpected: 0,
          reportsSubmitted: 0,
          reportsMissing: 0,
          reportsCoveragePct: null,
        ),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Sin informes esperados en octubre'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('clubs row: gap caption and «de total» suffix', (tester) async {
      await _pump(tester);

      expect(find.text('Clubes operativos'), findsOneWidget);
      expect(find.text('Sin actividad este mes: 2'), findsOneWidget);
      expect(find.text('8 de 10'), findsOneWidget);
    });

    testWidgets('clubs row: everybody active shows the all-active caption', (
      tester,
    ) async {
      final d = dashboard(
        summary: metrics(
          operationalClubs: 5,
          nonOperationalClubs: 0,
          operationalRatePct: 100,
        ),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Todos con actividad este mes'), findsOneWidget);
      expect(find.text('5 de 5'), findsOneWidget);
    });

    testWidgets('clubs row: zero clubs has no caption', (tester) async {
      final d = dashboard(
        summary: metrics(
          clubsTotal: 3,
          operationalClubs: 0,
          nonOperationalClubs: 0,
          operationalRatePct: null,
        ),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Todos con actividad este mes'), findsNothing);
      expect(find.textContaining('Sin actividad este mes:'), findsNothing);
      expect(find.text('0 de 0'), findsOneWidget);
    });

    testWidgets('people and classes rows show their captions and values', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Personas activas'), findsOneWidget);
      expect(find.text('Con cuenta en la app: 210'), findsOneWidget);
      expect(find.text('320'), findsOneWidget);
      expect(find.text('Inscripciones a clases'), findsOneWidget);
      expect(find.text('Personas distintas: 140'), findsOneWidget);
      expect(find.text('150'), findsOneWidget);
    });

    testWidgets('large numbers are grouped by the Spanish locale', (
      tester,
    ) async {
      final d = dashboard(summary: metrics(peopleActive: 1234567));
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('1.234.567'), findsOneWidget);
    });
  });

  group('classes sheet', () {
    testWidgets('opens grouped by club type, only classes with enrollments', (
      tester,
    ) async {
      final d = dashboard(
        summary: metrics(
          classes: [
            classRow(1, 'Amigo', count: 4),
            classRow(2, 'Compañero', count: 6),
            classRow(3, 'Explorador', count: 0),
            classRow(4, 'Abeja',
                clubTypeId: 2, clubTypeName: 'Aventureros', count: 9),
          ],
        ),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(_isTappable(tester, 'Inscripciones a clases'), isTrue);
      await tester.tap(find.text('Inscripciones a clases'));
      await tester.pumpAndSettle();

      expect(find.text('Inscripciones por clase'), findsOneWidget);
      expect(find.text('Amigo'), findsOneWidget);
      expect(find.text('Compañero'), findsOneWidget);
      expect(find.text('Abeja'), findsOneWidget);
      expect(find.text('Explorador'), findsNothing);
      expect(find.text('CONQUISTADORES'), findsOneWidget);
      expect(find.text('AVENTUREROS'), findsOneWidget);
      // Eyebrow total = people enrolled in the group.
      expect(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('10'),
        ),
        findsOneWidget,
      );
      expectNoLayoutException(tester);
    });

    testWidgets('is not tappable when no class has enrollments', (
      tester,
    ) async {
      final d = dashboard(
        summary: metrics(classes: [classRow(1, 'Amigo', count: 0)]),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(_isTappable(tester, 'Inscripciones a clases'), isFalse);
      await tester.tap(find.text('Inscripciones a clases'));
      await tester.pumpAndSettle();
      expect(find.text('Inscripciones por clase'), findsNothing);
    });

    testWidgets('is not tappable with an empty class list', (tester) async {
      await _pump(tester);

      expect(_isTappable(tester, 'Inscripciones a clases'), isFalse);
    });
  });

  group('children', () {
    testWidgets('union children: label and row texts', (tester) async {
      final d = dashboard(
        level: SupervisionTerritoryLevel.division,
        scopeName: 'División Sur',
        children: [
          opsChild(5, 'Unión Este', _union),
          opsChild(
            6,
            'Unión Oeste',
            _union,
            m: metrics(
              reportsExpected: 0,
              reportsCoveragePct: null,
              reportsMissing: 0,
              operationalClubs: 4,
              nonOperationalClubs: 0,
            ),
          ),
        ],
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('UNIONES'), findsOneWidget);
      expect(find.text('Unión Este'), findsOneWidget);
      expect(find.text('Informes 75% · Operativos: 8 de 10'), findsOneWidget);
      expect(find.text('Unión Oeste'), findsOneWidget);
      expect(find.text('Sin informes esperados · Operativos: 4 de 4'),
          findsOneWidget);
    });

    testWidgets('local field children use their own label', (tester) async {
      final d = dashboard(children: [opsChild(5, 'Campo A', _localField)]);
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('CAMPOS LOCALES'), findsOneWidget);
    });

    testWidgets('club children: label and row texts', (tester) async {
      final d = dashboard(
        level: _localField,
        children: [
          opsChild(
            11,
            'Club Orión',
            _club,
            m: metrics(
              reportsExpected: 2,
              reportsSubmitted: 1,
              reportsMissing: 1,
              nonOperationalClubs: 0,
              operationalClubs: 1,
            ),
          ),
          opsChild(
            12,
            'Club Sirio',
            _club,
            m: metrics(
              reportsExpected: 0,
              reportsMissing: 0,
              nonOperationalClubs: 1,
              operationalClubs: 0,
            ),
          ),
        ],
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('CLUBES'), findsOneWidget);
      expect(find.text('Informes: 1 de 2 · Con actividad este mes'),
          findsOneWidget);
      expect(find.text('Sin informes esperados · Sin actividad este mes'),
          findsOneWidget);
    });

    testWidgets('no children hides the section', (tester) async {
      await _pump(tester);

      expect(find.text('UNIONES'), findsNothing);
      expect(find.text('CAMPOS LOCALES'), findsNothing);
    });

    testWidgets('tapping a union child pushes its operations scope', (
      tester,
    ) async {
      final d = dashboard(
        level: SupervisionTerritoryLevel.division,
        children: [opsChild(5, 'Unión Este', _union)],
      );
      await _pump(tester, repo: _repoWith(d));

      await tester.tap(find.text('Unión Este'));
      await tester.pumpAndSettle();

      expect(
          find.text('ops:/supervision/operations?union_id=5'), findsOneWidget);
    });

    testWidgets('tapping a local field child pushes its operations scope', (
      tester,
    ) async {
      final d = dashboard(children: [opsChild(8, 'Campo A', _localField)]);
      await _pump(tester, repo: _repoWith(d));

      await tester.tap(find.text('Campo A'));
      await tester.pumpAndSettle();

      expect(find.text('ops:/supervision/operations?local_field_id=8'),
          findsOneWidget);
    });

    testWidgets('a club child opens the club only with clubs.view_territory', (
      tester,
    ) async {
      final d = dashboard(
        level: _localField,
        children: [opsChild(11, 'Club Orión', _club)],
      );
      await _pump(
        tester,
        repo: _repoWith(d),
        capabilities: const [kSupervisionAppView, kViewTerritoryCap],
      );

      expect(_isTappable(tester, 'Club Orión'), isTrue);
      await tester.tap(find.text('Club Orión'));
      await tester.pumpAndSettle();

      expect(find.text('club:11'), findsOneWidget);
    });

    testWidgets('a club child is inert without clubs.view_territory', (
      tester,
    ) async {
      final d = dashboard(
        level: _localField,
        children: [opsChild(11, 'Club Orión', _club)],
      );
      await _pump(tester, repo: _repoWith(d));

      expect(_isTappable(tester, 'Club Orión'), isFalse);
      await tester.tap(find.text('Club Orión'));
      await tester.pumpAndSettle();

      expect(find.text('club:11'), findsNothing);
      expect(find.text('Club Orión'), findsOneWidget);
    });
  });

  group('more indicators', () {
    testWidgets('shows the period facts and honors rows', (tester) async {
      await _pump(tester);

      expect(find.text('MÁS INDICADORES'), findsOneWidget);
      expect(find.text('Clubes registrados'), findsOneWidget);
      expect(find.text('Secciones con actividad'), findsOneWidget);
      expect(find.text('Actividades registradas'), findsOneWidget);
      expect(find.text('Especialidades en revisión'), findsOneWidget);
      expect(find.text('Especialidades aprobadas'), findsOneWidget);
    });

    testWidgets('honors rows are hidden when honors are not available', (
      tester,
    ) async {
      final d = dashboard(summary: metrics(honorsAvailable: false));
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Clubes registrados'), findsOneWidget);
      expect(find.text('Especialidades en revisión'), findsNothing);
      expect(find.text('Especialidades aprobadas'), findsNothing);
    });

    testWidgets('a null honors figure hides only its row', (tester) async {
      final d = dashboard(summary: metrics(honorsPendingReview: null));
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Especialidades en revisión'), findsNothing);
      expect(find.text('Especialidades aprobadas'), findsOneWidget);
    });

    testWidgets('year note shows a single year', (tester) async {
      final d = dashboard(
        period: reportingPeriod(
          yearStart: DateTime(2026, 1, 1),
          yearEnd: DateTime(2026, 12, 31),
        ),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Año eclesiástico 2026'), findsOneWidget);
    });

    testWidgets('year note shows a range when the year crosses a new year', (
      tester,
    ) async {
      final d = dashboard(
        period: reportingPeriod(
          yearStart: DateTime(2026, 7, 1),
          yearEnd: DateTime(2027, 6, 30),
        ),
      );
      await _pump(tester, repo: _repoWith(d));

      expect(find.text('Año eclesiástico 2026-2027'), findsOneWidget);
    });

    testWidgets('no year dates shows no year note', (tester) async {
      await _pump(tester);

      expect(find.textContaining('Año eclesiástico'), findsNothing);
    });
  });

  group('layout', () {
    SupervisionOperationsDashboard stress() {
      final longName =
          'Asociación ${'Metropolitana del Pacífico Sur ' * 3}'.trim();
      final big = metrics(
        clubsTotal: 1234567,
        operationalClubs: 1234000,
        nonOperationalClubs: 567,
        peopleActive: 1234567,
        accountsActive: 1234567,
        classEnrollments: 1234567,
        classDistinctPeople: 1234567,
        reportsExpected: 1234567,
        reportsSubmitted: 1234000,
        reportsMissing: 567,
        operationalSections: 1234567,
        activitiesRegistered: 1234567,
        honorsPendingReview: 1234567,
        honorsApproved: 1234567,
        classes: [
          classRow(1, longName, clubTypeName: longName, count: 1234567),
        ],
      );
      return dashboard(
        level: _localField,
        scopeId: 3,
        scopeName: longName,
        path: [
          SupervisionScopeNode(
            level: SupervisionTerritoryLevel.division,
            id: 1,
            name: longName,
          ),
          SupervisionScopeNode(level: _union, id: 2, name: longName),
          SupervisionScopeNode(level: _localField, id: 3, name: longName),
        ],
        summary: big,
        children: [
          opsChild(11, longName, _club, m: big),
          opsChild(12, 'Club $longName', _club, m: big),
        ],
        period: reportingPeriod(
          yearStart: DateTime(2026, 7, 1),
          yearEnd: DateTime(2027, 6, 30),
        ),
      );
    }

    testWidgets('no overflow at 320x640 with text scale 2.0 (own scope)', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(stress()),
        size: const Size(320, 640),
        textScale: 2.0,
        capabilities: const [kSupervisionAppView, kViewTerritoryCap],
      );

      expect(find.text('INDICADORES'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('no overflow at 320x640 with text scale 2.0 (drilled scope)', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(stress()),
        query: const SupervisionOperationsQuery(localFieldId: 3),
        size: const Size(320, 640),
        textScale: 2.0,
      );

      expect(find.text('INDICADORES'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('no overflow in the classes sheet at 320x640 scale 2.0', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(stress()),
        size: const Size(320, 640),
        textScale: 2.0,
      );

      await tester.dragUntilVisible(
        find.text('Inscripciones a clases'),
        find.byType(CustomScrollView),
        const Offset(0, -200),
      );
      // Out of the frosted top bar's area.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 250));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inscripciones a clases'));
      await tester.pumpAndSettle();

      expect(find.text('Inscripciones por clase'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('on a tablet the content is at most 640 wide', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(stress()),
        size: const Size(1024, 1400),
      );

      expect(find.text('INDICADORES'), findsOneWidget);
      final sections = find.byType(SacGroupedSection);
      expect(sections, findsWidgets);
      for (final element in sections.evaluate()) {
        final width = tester.getSize(find.byWidget(element.widget)).width;
        expect(width, lessThanOrEqualTo(640));
      }
      expectNoLayoutException(tester);
    });
  });
}
