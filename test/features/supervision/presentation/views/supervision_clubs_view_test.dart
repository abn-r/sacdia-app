/// Widget tests for the territorial clubs directory.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_clubs_view.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_club_list_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_identity_tiles.dart';

import 'supervision_territory_test_harness.dart';
import 'supervision_view_test_harness.dart';

Future<FakeClubsRepo> _pump(
  WidgetTester tester, {
  FakeClubsRepo? repo,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeClubsRepo();
  await pumpTerritoryApp(
    tester,
    home: const SupervisionClubsView(),
    clubsRepo: fake,
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

FakeClubsRepo _repoWith(List<SupervisionClubListItem> items) =>
    FakeClubsRepo()..onClubs = (_) async => Right(clubPage(items));

Finder _chip(String label) => find.widgetWithText(SacFilterChip, label);

Finder _row(String name) => find.widgetWithText(SacListRow, name);

/// Count drawn on a filter chip, or null when it has none.
int? _chipCount(WidgetTester tester, String label) =>
    tester.widget<SacFilterChip>(_chip(label)).count;

void main() {
  setUpAll(initSupervisionViewTests);

  group('load states', () {
    testWidgets('shows the skeleton, then the cards', (tester) async {
      final gate = Completer<SupervisionClubPage>();
      final repo = FakeClubsRepo()
        ..onClubs = (_) async => Right(await gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);

      gate.complete(clubPage([clubItem(1)]));
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Club 1'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('requests the first page unfiltered and without search', (
      tester,
    ) async {
      final repo = await _pump(tester);

      expect(repo.calls, hasLength(1));
      expect(repo.calls.single.page, 1);
      expect(repo.calls.single.filter, SupervisionClubActiveFilter.all);
      expect(repo.calls.single.search, '');
    });

    testWidgets('shows the error state and retry reloads the list', (
      tester,
    ) async {
      final repo = FakeClubsRepo();
      repo.onClubs = (_) async => repo.calls.length == 1
          ? const Left(kTerritoryBoom)
          : Right(clubPage([clubItem(1)]));
      await _pump(tester, repo: repo);

      expect(find.text('No se pudieron cargar los clubes'), findsOneWidget);
      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(2));
      expect(find.text('No se pudieron cargar los clubes'), findsNothing);
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = FakeClubsRepo()
        ..onClubs = (_) async => const Left(kTerritoryForbidden);
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudieron cargar los clubes'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('empty states', () {
    testWidgets('no clubs shows «Sin clubes»', (tester) async {
      await _pump(tester, repo: _repoWith(const []));

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('Sin clubes'), findsOneWidget);
      expect(find.text('No hay clubes que mostrar en tu territorio.'),
          findsOneWidget);
    });

    testWidgets('no inactive clubs shows its own title', (tester) async {
      final repo = FakeClubsRepo()
        ..onClubs = (call) async => Right(
              clubPage(
                call.filter == SupervisionClubActiveFilter.inactive
                    ? const []
                    : [clubItem(1)],
              ),
            );
      await _pump(tester, repo: repo);

      await tester.tap(_chip('Inactivos'));
      await tester.pumpAndSettle();

      expect(find.text('Sin clubes inactivos'), findsOneWidget);
      expect(find.text('Sin clubes'), findsNothing);
    });

    testWidgets('a search without results shows «Sin resultados»', (
      tester,
    ) async {
      final repo = FakeClubsRepo()
        ..onClubs = (call) async => Right(
              clubPage(call.search.isEmpty ? [clubItem(1)] : const []),
            );
      await _pump(tester, repo: repo);

      await tester.enterText(find.byType(TextFormField), 'zzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(find.text('Sin resultados'), findsOneWidget);
      expect(
        find.text(
          'Prueba con otro nombre de club, iglesia, distrito o campo local.',
        ),
        findsOneWidget,
      );
      expect(find.text('Club 1'), findsNothing);
    });
  });

  group('rows', () {
    testWidgets('show name, place and the logos of the active sections', (
      tester,
    ) async {
      final repo = _repoWith([
        clubItem(
          1,
          name: 'Club Orión',
          church: 'Iglesia Central',
          district: 'Distrito 4',
          localField: 'Asociación Norte',
          sections: [
            clubSection(1, 'Conquistadores'),
            clubSection(2, 'Aventureros'),
            clubSection(3, 'Guías Mayores', active: false),
          ],
        ),
      ]);
      await _pump(tester, repo: repo);

      expect(find.text('Club Orión'), findsOneWidget);
      expect(find.text('Iglesia Central · Distrito 4'), findsOneWidget);
      // The local field is the group, not a line of the row.
      expect(find.text('ASOCIACIÓN NORTE'), findsOneWidget);
      final logos = find.descendant(
        of: _row('Club Orión'),
        matching: find.byType(SupervisionClubTypeLogo),
      );
      expect(
        tester
            .widgetList<SupervisionClubTypeLogo>(logos)
            .map((l) => l.typeName),
        ['Conquistadores', 'Aventureros'],
      );
      expect(find.byType(SupervisionMonogram), findsOneWidget);
      expect(find.text('CL'), findsOneWidget);
      expect(find.text('Inactivo'), findsNothing);
    });

    testWidgets('a club without active sections says so', (tester) async {
      final repo = _repoWith([
        clubItem(1,
            sections: [clubSection(1, 'Conquistadores', active: false)]),
        clubItem(2, sections: const []),
      ]);
      await _pump(tester, repo: repo);

      expect(find.text('Sin secciones activas'), findsNothing);
      expect(
        find.textContaining('Sin secciones activas'),
        findsNWidgets(2),
      );
    });

    testWidgets('an inactive club is dimmed and carries the «Inactivo» chip', (
      tester,
    ) async {
      final repo = _repoWith([
        clubItem(1, name: 'Club Activo'),
        clubItem(2, name: 'Club Cerrado', active: false),
      ]);
      await _pump(tester, repo: repo);

      expect(find.text('Inactivo'), findsOneWidget);
      expect(
        find.descendant(
          of: _row('Club Cerrado'),
          matching: find.text('Inactivo'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<SupervisionMonogram>(find.descendant(
              of: _row('Club Cerrado'),
              matching: find.byType(SupervisionMonogram),
            ))
            .dimmed,
        isTrue,
      );
      // An inactive club still opens its summary.
      await tester.tap(find.text('Club Cerrado'));
      await tester.pumpAndSettle();
      expect(find.text('club:2'), findsOneWidget);
    });

    testWidgets('blank church and district hide the place line', (
      tester,
    ) async {
      final repo = _repoWith([
        clubItem(1, church: ' ', district: '', localField: ''),
      ]);
      await _pump(tester, repo: repo);

      expect(find.textContaining(' · Distrito'), findsNothing);
      expect(find.text('ASOCIACIÓN NORTE'), findsNothing);
      // A club with no local field falls under the generic «Clubes» group.
      expect(find.text('CLUBES'), findsOneWidget);
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('tapping a row pushes the club detail', (tester) async {
      await _pump(tester, repo: _repoWith([clubItem(42, name: 'Club Sirio')]));

      await tester.tap(find.text('Club Sirio'));
      await tester.pumpAndSettle();

      expect(find.text('club:42'), findsOneWidget);
    });
  });

  group('grouping by local field', () {
    test('sorts by field then name and keeps the server order on ties', () {
      final groups = groupSupervisionClubsByField([
        clubItem(1, name: 'Zeta', localField: 'Sur'),
        clubItem(2, name: 'Beta', localField: 'Norte'),
        clubItem(3, name: 'Alfa', localField: 'Sur'),
        clubItem(4, name: 'Beta', localField: 'Norte'),
        clubItem(5, name: 'Alfa', localField: 'Norte'),
      ]);

      expect(groups.map((g) => g.localFieldName), ['Norte', 'Sur']);
      expect(groups[0].clubs.map((c) => c.id), [5, 2, 4]);
      expect(groups[1].clubs.map((c) => c.id), [3, 1]);
    });

    testWidgets('one section per field with its club count', (tester) async {
      final repo = _repoWith([
        clubItem(1, name: 'Orión', localField: 'Asociación del Golfo'),
        clubItem(2, name: 'Vega', localField: 'Misión Istmo'),
        clubItem(3, name: 'Diamantes', localField: 'Asociación del Golfo'),
      ]);
      await _pump(tester, repo: repo);

      expect(find.byType(SacGroupedSection), findsNWidgets(2));
      expect(find.text('ASOCIACIÓN DEL GOLFO'), findsOneWidget);
      expect(find.text('MISIÓN ISTMO'), findsOneWidget);
      final golfo = find.ancestor(
        of: find.text('ASOCIACIÓN DEL GOLFO'),
        matching: find.byType(SacGroupedSection),
      );
      expect(
        find.descendant(of: golfo, matching: find.text('2')),
        findsOneWidget,
      );
      // Sorted by name inside the field.
      expect(
        tester.getTopLeft(find.text('Diamantes')).dy,
        lessThan(tester.getTopLeft(find.text('Orión')).dy),
      );
    });

    testWidgets('with more pages to load the group counts are hidden', (
      tester,
    ) async {
      final gate = Completer<SupervisionClubPage>();
      final repo = FakeClubsRepo()
        ..onClubs = (call) async => call.page == 1
            ? Right(
                clubPage([clubItem(1), clubItem(2)], total: 3, hasMore: true))
            : Right(await gate.future);
      // The footer spinner never settles while page 2 is pending.
      await _pump(tester, repo: repo, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      final section = find.byType(SacGroupedSection);
      expect(section, findsOneWidget);
      expect(
        find.descendant(of: section, matching: find.text('2')),
        findsNothing,
      );

      gate.complete(clubPage([clubItem(3)], page: 2, total: 3));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: section, matching: find.text('3')),
        findsOneWidget,
      );
    });

    testWidgets('a club that arrives later joins its field group', (
      tester,
    ) async {
      final repo = FakeClubsRepo()
        ..onClubs = (call) async => call.page == 1
            ? Right(clubPage(
                [
                  clubItem(1, name: 'Orión', localField: 'Sur'),
                  clubItem(2, name: 'Vega', localField: 'Norte'),
                ],
                total: 3,
                hasMore: true,
              ))
            : Right(clubPage(
                [clubItem(3, name: 'Diamantes', localField: 'Sur')],
                page: 2,
                total: 3,
              ));
      await _pump(tester, repo: repo);

      expect(find.byType(SacGroupedSection), findsNWidgets(2));
      final sur = find.ancestor(
        of: find.text('SUR'),
        matching: find.byType(SacGroupedSection),
      );
      expect(
        find.descendant(of: sur, matching: find.text('Diamantes')),
        findsOneWidget,
      );
    });
  });

  group('filter counts', () {
    testWidgets('only the selected chip shows the server total', (
      tester,
    ) async {
      final repo = FakeClubsRepo()
        ..onClubs = (call) async => Right(
              clubPage([clubItem(1), clubItem(2)],
                  total:
                      call.filter == SupervisionClubActiveFilter.all ? 21 : 19),
            );
      await _pump(tester, repo: repo);

      expect(_chipCount(tester, 'Todos'), 21);
      expect(_chipCount(tester, 'Activos'), isNull);
      expect(_chipCount(tester, 'Inactivos'), isNull);

      await tester.tap(_chip('Activos'));
      await tester.pumpAndSettle();
      expect(_chipCount(tester, 'Activos'), 19);
      expect(_chipCount(tester, 'Todos'), isNull);
    });
  });

  group('filters', () {
    testWidgets('each chip requests the list with its filter', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(_chip('Activos'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.filter, SupervisionClubActiveFilter.active);
      expect(repo.calls.last.page, 1);

      await tester.tap(_chip('Inactivos'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.filter, SupervisionClubActiveFilter.inactive);

      await tester.tap(_chip('Todos'));
      await tester.pumpAndSettle();
      expect(repo.calls.last.filter, SupervisionClubActiveFilter.all);
      expect(repo.calls, hasLength(4));
    });

    testWidgets('tapping the selected chip does not reload', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(_chip('Todos'));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(1));
    });

    testWidgets('the list stays visible while a filter reloads', (
      tester,
    ) async {
      final gate = Completer<SupervisionClubPage>();
      final repo = FakeClubsRepo();
      repo.onClubs = (_) async => repo.calls.length == 1
          ? Right(clubPage([clubItem(1)]))
          : Right(await gate.future);
      await _pump(tester, repo: repo);

      await tester.tap(_chip('Activos'));
      await tester.pump();

      expect(find.text('Club 1'), findsOneWidget);
      expect(find.byType(SacSkeletonList), findsNothing);

      gate.complete(clubPage([clubItem(2)]));
      await tester.pumpAndSettle();
      expect(find.text('Club 1'), findsNothing);
      expect(find.text('Club 2'), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('typing triggers ONE request after the debounce, trimmed', (
      tester,
    ) async {
      final repo = await _pump(tester);
      expect(repo.calls, hasLength(1));

      await tester.enterText(find.byType(TextFormField), '  Orión  ');
      await tester.pump(const Duration(milliseconds: 100));
      expect(repo.calls, hasLength(1));

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.search, 'Orión');
      expect(repo.calls.last.page, 1);
    });

    testWidgets('successive keystrokes inside the debounce collapse to one', (
      tester,
    ) async {
      final repo = await _pump(tester);

      await tester.enterText(find.byType(TextFormField), 'o');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextFormField), 'or');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byType(TextFormField), 'ori');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.search, 'ori');
    });

    testWidgets('the filter is kept when searching', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(_chip('Activos'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'sirio');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.calls.last.filter, SupervisionClubActiveFilter.active);
      expect(repo.calls.last.search, 'sirio');
    });

    testWidgets('whitespace-only text does not request again', (tester) async {
      final repo = await _pump(tester);

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(repo.calls, hasLength(1));
    });
  });

  group('load more', () {
    testWidgets('appends the next page', (tester) async {
      final repo = FakeClubsRepo()
        ..onClubs = (call) async => call.page == 1
            ? Right(
                clubPage([clubItem(1), clubItem(2)], total: 3, hasMore: true))
            : Right(clubPage([clubItem(3)], page: 2, total: 3));
      await _pump(tester, repo: repo);

      expect(repo.calls.map((c) => c.page), [1, 2]);
      expect(find.text('Club 1'), findsOneWidget);
      expect(find.text('Club 2'), findsOneWidget);
      expect(find.text('Club 3'), findsOneWidget);
      expect(_chipCount(tester, 'Todos'), 3);
    });

    testWidgets('a failed page keeps the items and offers a retry', (
      tester,
    ) async {
      var failPage2 = true;
      final repo = FakeClubsRepo()
        ..onClubs = (call) async {
          if (call.page == 1) {
            return Right(
              clubPage([clubItem(1), clubItem(2)], total: 3, hasMore: true),
            );
          }
          return failPage2
              ? const Left(kTerritoryBoom)
              : Right(clubPage([clubItem(3)], page: 2, total: 3));
        };
      await _pump(tester, repo: repo);

      expect(find.text('Club 1'), findsOneWidget);
      expect(find.text('Club 2'), findsOneWidget);
      expect(find.text('No se pudieron cargar más clubes.'), findsOneWidget);
      expect(find.byType(SacErrorState), findsNothing);
      // The failed page waits for the retry button instead of looping.
      expect(repo.calls.map((c) => c.page), [1, 2]);

      failPage2 = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(find.text('Club 3'), findsOneWidget);
      expect(find.text('No se pudieron cargar más clubes.'), findsNothing);
      expect(repo.calls.map((c) => c.page), [1, 2, 2]);
    });
  });

  group('layout', () {
    testWidgets('no overflow at 320x640 with text scale 2.0 and long names', (
      tester,
    ) async {
      final long = 'Metropolitano del Pacífico Sur ' * 4;
      final repo = _repoWith([
        for (var i = 1; i <= 3; i++)
          clubItem(
            i,
            name: 'Club $long',
            active: i != 2,
            church: 'Iglesia $long',
            district: 'Distrito $long',
            localField: 'Asociación $long',
            sections: [
              clubSection(1, 'Conquistadores del Pacífico Sur Metropolitano'),
              clubSection(2, 'Aventureros del Pacífico Sur Metropolitano'),
              clubSection(3, 'Guías Mayores del Pacífico Sur Metropolitano'),
            ],
          ),
      ]);
      await _pump(
        tester,
        repo: repo,
        size: const Size(320, 640),
        textScale: 2.0,
      );

      expect(find.byType(SacSkeletonList), findsNothing);
      expectNoLayoutException(tester);
    });

    testWidgets('no overflow in the empty and error states at 320x640 x2', (
      tester,
    ) async {
      final repo = FakeClubsRepo()
        ..onClubs = (_) async => const Left(kTerritoryBoom);
      await _pump(
        tester,
        repo: repo,
        size: const Size(320, 640),
        textScale: 2.0,
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('on a tablet the groups are at most 640 wide', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([clubItem(1, name: 'Club Orión')]),
        size: const Size(1024, 1000),
      );

      final width = tester.getSize(find.byType(SacGroupedSection)).width;
      expect(width, lessThanOrEqualTo(640));
    });
  });
}
