/// Widget tests for the territorial club summary.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_club_detail_view.dart';

import 'supervision_territory_test_harness.dart';
import 'supervision_view_test_harness.dart';

Future<FakeClubsRepo> _pump(
  WidgetTester tester, {
  FakeClubsRepo? repo,
  String clubId = '7',
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeClubsRepo();
  await pumpTerritoryApp(
    tester,
    home: SupervisionClubDetailView(clubId: clubId),
    clubsRepo: fake,
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

FakeClubsRepo _repoWith(SupervisionClubSummary summary) =>
    FakeClubsRepo()..onSummary = (_) async => Right(summary);

SupervisionClubLeadership _leadership({
  SupervisionClubLeader? director,
  List<SupervisionClubLeader> deputies = const [],
  List<SupervisionClubLeader> secretaries = const [],
}) =>
    SupervisionClubLeadership(
      director: director,
      deputies: deputies,
      secretaries: secretaries,
    );

void main() {
  setUpAll(initSupervisionViewTests);

  group('load states', () {
    testWidgets('a non-numeric club id shows the error without a request', (
      tester,
    ) async {
      final repo = await _pump(tester, clubId: 'abc');

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('No se pudo cargar el club'), findsOneWidget);
      expect(find.text('Resumen del club'), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(repo.summaryCalls, isEmpty);
    });

    testWidgets('shows the skeleton, then the summary', (tester) async {
      final gate = Completer<SupervisionClubSummary>();
      final repo = FakeClubsRepo()
        ..onSummary = (_) async => Right(await gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('CLUB'), findsNothing);

      gate.complete(clubSummary());
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('CLUB'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('requests the summary of the numeric id', (tester) async {
      final repo = await _pump(tester, clubId: '42');

      expect(repo.summaryCalls, [42]);
    });

    testWidgets('shows the error state and retry reloads the summary', (
      tester,
    ) async {
      final repo = FakeClubsRepo();
      repo.onSummary = (_) async => repo.summaryCalls.length == 1
          ? const Left(kTerritoryBoom)
          : Right(clubSummary());
      await _pump(tester, repo: repo);

      expect(find.text('No se pudo cargar el club'), findsOneWidget);
      expect(find.text('CLUB'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.summaryCalls, hasLength(2));
      expect(find.text('No se pudo cargar el club'), findsNothing);
      expect(find.text('CLUB'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = FakeClubsRepo()
        ..onSummary = (_) async => const Left(kTerritoryForbidden);
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudo cargar el club'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('a failed pull-to-refresh keeps the old summary', (
      tester,
    ) async {
      final repo = FakeClubsRepo();
      repo.onSummary = (_) async => repo.summaryCalls.length == 1
          ? Right(clubSummary())
          : const Left(kTerritoryBoom);
      await _pump(tester, repo: repo);

      final refreshing = tester
          .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
          .show();
      await tester.pumpAndSettle();
      await refreshing;
      await tester.pumpAndSettle();

      expect(repo.summaryCalls, hasLength(2));
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.text('CLUB'), findsOneWidget);
      expect(find.text('Club Orión'), findsOneWidget);
    });
  });

  group('top bar', () {
    testWidgets('shows the club name with «Resumen del club» as subtitle', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(clubSummary(profile: clubProfile(name: 'Club Orión'))),
      );

      expect(find.text('Club Orión'), findsOneWidget);
      expect(find.text('Resumen del club'), findsOneWidget);
    });

    testWidgets('while loading the title is «Resumen del club»', (
      tester,
    ) async {
      final gate = Completer<SupervisionClubSummary>();
      final repo = FakeClubsRepo()
        ..onSummary = (_) async => Right(await gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.text('Resumen del club'), findsOneWidget);
      gate.complete(clubSummary());
      await tester.pumpAndSettle();
    });
  });

  group('club group', () {
    testWidgets('shows status, church, district, local field and address', (
      tester,
    ) async {
      await _pump(tester, repo: _repoWith(clubSummary()));

      expect(find.text('CLUB'), findsOneWidget);
      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Activo'), findsOneWidget);
      expect(find.text('Iglesia'), findsOneWidget);
      expect(find.text('Iglesia Central'), findsOneWidget);
      expect(find.text('Distrito'), findsOneWidget);
      expect(find.text('Distrito 1'), findsOneWidget);
      expect(find.text('Campo local'), findsOneWidget);
      expect(find.text('Asociación Norte'), findsOneWidget);
      expect(find.text('Dirección'), findsOneWidget);
      expect(find.text('Calle 1 #23'), findsOneWidget);
    });

    testWidgets('an inactive club shows «Inactivo»', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(clubSummary(profile: clubProfile(active: false))),
      );

      expect(find.text('Inactivo'), findsOneWidget);
      expect(find.text('Activo'), findsNothing);
    });

    testWidgets('no address hides the «Dirección» row', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(clubSummary(profile: clubProfile(address: null))),
      );

      expect(find.text('Dirección'), findsNothing);
      expect(find.text('Iglesia'), findsOneWidget);
    });

    testWidgets('empty church, district and local field hide their rows', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          clubSummary(
            profile: clubProfile(
              church: '',
              district: '',
              localField: '',
              address: null,
            ),
          ),
        ),
      );

      expect(find.text('Estado'), findsOneWidget);
      expect(find.text('Iglesia'), findsNothing);
      expect(find.text('Distrito'), findsNothing);
      expect(find.text('Campo local'), findsNothing);
    });
  });

  group('figures group', () {
    testWidgets('shows the counts and the attendance as a percentage', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          clubSummary(
            overview: clubOverview(
              activeMembers: 40,
              invested: 6,
              pending: 2,
              attendance: 87.5,
            ),
          ),
        ),
      );

      expect(find.text('EN CIFRAS'), findsOneWidget);
      expect(find.text('Miembros activos'), findsOneWidget);
      expect(find.text('40'), findsOneWidget);
      expect(find.text('Investidos este año'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Solicitudes de cargo pendientes'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('Asistencia promedio'), findsOneWidget);
      expect(find.text('87%'), findsOneWidget);
      expect(find.textContaining('No se pudieron cargar las cifras'),
          findsNothing);
    });

    testWidgets('null attendance hides only that row', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          clubSummary(overview: clubOverview(attendance: null)),
        ),
      );

      expect(find.text('Miembros activos'), findsOneWidget);
      expect(find.text('Asistencia promedio'), findsNothing);
    });

    testWidgets('attendance never rounds up to 100%', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          clubSummary(overview: clubOverview(attendance: 99.9)),
        ),
      );

      expect(find.text('99%'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
    });

    testWidgets('large counts are grouped by the Spanish locale', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          clubSummary(overview: clubOverview(activeMembers: 1234567)),
        ),
      );

      expect(find.text('1.234.567'), findsOneWidget);
    });

    testWidgets('null overview shows the note and no figures group', (
      tester,
    ) async {
      await _pump(tester, repo: _repoWith(clubSummary()));

      expect(
        find.text(
          'No se pudieron cargar las cifras del club. '
          'Desliza hacia abajo para reintentar.',
        ),
        findsOneWidget,
      );
      expect(find.text('EN CIFRAS'), findsNothing);
      expect(find.text('Miembros activos'), findsNothing);
      // The club itself still shows.
      expect(find.text('CLUB'), findsOneWidget);
    });
  });

  group('sections group', () {
    testWidgets('lists sections with inactive mark and member target', (
      tester,
    ) async {
      final profile = clubProfile(
        sections: [
          clubSection(1, 'Conquistadores', soulsTarget: 1500),
          clubSection(2, 'Aventureros', active: false),
          clubSection(3, 'Guías Mayores', active: false, soulsTarget: 20),
          clubSection(4, 'Otra', soulsTarget: 0),
          clubSection(5, ''),
        ],
      );
      await _pump(tester, repo: _repoWith(clubSummary(profile: profile)));

      expect(find.text('SECCIONES'), findsOneWidget);
      expect(find.text('Conquistadores'), findsOneWidget);
      expect(find.text('Meta de miembros: 1.500'), findsOneWidget);
      expect(find.text('Aventureros'), findsOneWidget);
      expect(find.text('Inactiva'), findsOneWidget);
      expect(find.text('Inactiva · Meta de miembros: 20'), findsOneWidget);
      // A zero target is not shown.
      expect(find.text('Otra'), findsOneWidget);
      expect(find.textContaining('Meta de miembros: 0'), findsNothing);
      // A section without type name falls back to «Sección».
      expect(find.text('Sección'), findsOneWidget);
    });

    testWidgets('no sections hides the group', (tester) async {
      await _pump(tester, repo: _repoWith(clubSummary()));

      expect(find.text('SECCIONES'), findsNothing);
    });
  });

  group('leadership group', () {
    testWidgets('lists director, deputies and secretaries with role label', (
      tester,
    ) async {
      final leadership = _leadership(
        director: leader('Ana Pérez', section: 'Conquistadores'),
        deputies: [leader('Luis Gómez', section: 'Aventureros')],
        secretaries: [leader('Marta Ruiz')],
      );
      await _pump(
        tester,
        repo: _repoWith(clubSummary(leadership: leadership)),
      );

      expect(find.text('DIRECTIVA'), findsOneWidget);
      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Director · Conquistadores'), findsOneWidget);
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('Subdirector · Aventureros'), findsOneWidget);
      expect(find.text('Marta Ruiz'), findsOneWidget);
      expect(find.text('Secretaría'), findsOneWidget);
    });

    testWidgets('null leadership hides the group', (tester) async {
      await _pump(tester, repo: _repoWith(clubSummary()));

      expect(find.text('DIRECTIVA'), findsNothing);
    });

    testWidgets('empty leadership hides the group', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(clubSummary(leadership: _leadership())),
      );

      expect(find.text('DIRECTIVA'), findsNothing);
    });

    testWidgets('leaders without a name are skipped', (tester) async {
      final leadership = _leadership(
        director: leader('  '),
        deputies: [leader('Luis Gómez')],
      );
      await _pump(
        tester,
        repo: _repoWith(clubSummary(leadership: leadership)),
      );

      expect(find.text('DIRECTIVA'), findsOneWidget);
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('Director'), findsNothing);
    });

    testWidgets('only blank names hides the group', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          clubSummary(leadership: _leadership(director: leader(' '))),
        ),
      );

      expect(find.text('DIRECTIVA'), findsNothing);
    });
  });

  group('events group', () {
    testWidgets('lists upcoming activities with a formatted date', (
      tester,
    ) async {
      final date = DateTime(2026, 11, 12);
      final formatted = DateFormat.yMMMd('es').format(date);
      await _pump(
        tester,
        repo: _repoWith(
          clubSummary(
            overview: clubOverview(
              events: [
                SupervisionClubEvent(
                  id: 1,
                  name: 'Campamento',
                  date: date,
                  sectionName: 'Conquistadores',
                ),
                const SupervisionClubEvent(
                  id: 2,
                  name: 'Reunión sin fecha',
                  date: null,
                  sectionName: null,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('PRÓXIMAS ACTIVIDADES'), findsOneWidget);
      expect(find.text('Campamento'), findsOneWidget);
      expect(find.text('$formatted · Conquistadores'), findsOneWidget);
      expect(formatted, contains('2026'));
      expect(find.text('Reunión sin fecha'), findsOneWidget);
    });

    testWidgets('no upcoming activities hides the group', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(clubSummary(overview: clubOverview())),
      );

      expect(find.text('PRÓXIMAS ACTIVIDADES'), findsNothing);
    });
  });

  group('layout', () {
    SupervisionClubSummary stress() {
      final long = 'Metropolitano del Pacífico Sur ' * 4;
      return clubSummary(
        profile: clubProfile(
          name: 'Club $long',
          church: 'Iglesia $long',
          district: 'Distrito $long',
          localField: 'Asociación $long',
          address: 'Avenida $long 1234567, esquina $long',
          sections: [
            clubSection(1, 'Conquistadores $long', soulsTarget: 1234567),
            clubSection(2, 'Aventureros $long', active: false),
          ],
        ),
        overview: clubOverview(
          activeMembers: 1234567,
          invested: 1234567,
          pending: 1234567,
          events: [
            SupervisionClubEvent(
              id: 1,
              name: 'Campamento $long',
              date: DateTime(2026, 11, 12),
              sectionName: 'Conquistadores $long',
            ),
          ],
        ),
        leadership: _leadership(
          director: leader('Director $long', section: long),
          deputies: [leader('Subdirector $long', section: long)],
          secretaries: [leader('Secretaria $long', section: long)],
        ),
      );
    }

    testWidgets('no overflow at 320x640 with text scale 2.0 and long text', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(stress()),
        size: const Size(320, 640),
        textScale: 2.0,
      );

      expect(find.text('CLUB'), findsOneWidget);
      expectNoLayoutException(tester);
    });

    testWidgets('no overflow in the error state at 320x640 with scale 2.0', (
      tester,
    ) async {
      await _pump(
        tester,
        clubId: 'abc',
        size: const Size(320, 640),
        textScale: 2.0,
      );

      expect(find.byType(SacErrorState), findsOneWidget);
      expectNoLayoutException(tester);
    });
  });
}
