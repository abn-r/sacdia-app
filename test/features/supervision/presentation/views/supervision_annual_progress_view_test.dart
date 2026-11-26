/// Widget tests for the territorial «Progreso anual» view: picking a union or
/// a local field, and the clubs of one local field with their breakdown.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_annual_progress.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_annual_progress_view.dart';
import 'package:sacdia_app/shared/models/catalogs/club_type_model.dart';

import 'supervision_reports_progress_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _narrow = Size(320, 640);
const _longName =
    'Asociación de Clubes Juveniles del Valle Grande y la Sierra Central '
    'del Oriente Lejano';

Future<FakeProgressRepo> _pump(
  WidgetTester tester, {
  Widget home = const SupervisionAnnualProgressView(),
  FakeProgressRepo? repo,
  AuthorizationTerritory? territory = kDivisionTerritory,
  bool noYear = false,
  List<ClubTypeModel> types = const [kConquistadores],
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeProgressRepo();
  await pumpProgressApp(
    tester,
    home: home,
    repo: fake,
    territory: territory,
    noYear: noYear,
    types: types,
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

String _longClub(int i) =>
    'Club de Conquistadores Estrella de la Mañana del Valle Grande y Lejano $i';

String _mediumClub(int i) =>
    'Club de Conquistadores Estrella de la Mañana del Valle Grande $i';

/// The leaf: the clubs of local field 11 (a Union user drilled down).
const _leaf = SupervisionAnnualProgressView(unionId: 3, localFieldId: 11);

FakeProgressRepo _repoWithClubs(List<SupervisionClubProgress> clubs) {
  final repo = FakeProgressRepo();
  repo.onProgress = (_) async =>
      Right(SupervisionAnnualProgress(configured: true, clubs: clubs));
  return repo;
}

Finder _sheet() => find.byType(BottomSheet);
Finder _inSheet(Finder f) => find.descendant(of: _sheet(), matching: f);

Future<void> _openClub(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initSupervisionViewTests);

  group('division level', () {
    testWidgets('lists the unions of the division with a hint', (tester) async {
      final repo = await _pump(tester);

      expect(repo.unionCalls, [5]);
      expect(find.text('Progreso anual'), findsWidgets);
      expect(
        find.text('Elige una unión para ver el avance de sus clubes.'),
        findsOneWidget,
      );
      expect(find.text('UNIONES'), findsOneWidget);
      expect(find.text('Unión Norte'), findsOneWidget);
      expect(find.text('Unión Sur'), findsOneWidget);
      expect(repo.localFieldCalls, isEmpty);
      expect(repo.progressCalls, isEmpty);
    });

    testWidgets('shows the skeleton while the unions load', (tester) async {
      final gate = Completer<List<SupervisionTerritoryOption>>();
      final repo = FakeProgressRepo()
        ..onUnions = (_) async => Right(await gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('Unión Norte'), findsNothing);

      gate.complete([territoryOption(1, 'Unión Norte')]);
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Unión Norte'), findsOneWidget);
    });

    testWidgets('tapping a union pushes the screen one level down', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Unión Sur'));
      await tester.pumpAndSettle();

      expect(
        find.text('landing:/supervision/annual-progress?union_id=2'),
        findsOneWidget,
      );
    });

    testWidgets('an empty division says so', (tester) async {
      final repo = FakeProgressRepo()..onUnions = (_) async => const Right([]);
      await _pump(tester, repo: repo);

      expect(find.text('Sin uniones en tu división'), findsOneWidget);
      expect(find.byType(SacEmptyState), findsOneWidget);
    });

    testWidgets('an error shows the error state and retry reloads', (
      tester,
    ) async {
      final repo = FakeProgressRepo();
      final ok = repo.onUnions;
      repo.onUnions = (id) async =>
          repo.unionCalls.length == 1 ? const Left(kBoom) : ok(id);
      await _pump(tester, repo: repo);

      expect(find.text('No se pudo cargar el progreso anual'), findsOneWidget);
      expect(find.text('Unión Norte'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.unionCalls, hasLength(2));
      expect(find.text('Unión Norte'), findsOneWidget);
    });

    testWidgets('a 403 shows the forbidden state', (tester) async {
      final repo = FakeProgressRepo()
        ..onUnions = (_) async => const Left(kForbidden);
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('union level', () {
    testWidgets('lists the local fields of the own union', (tester) async {
      final repo = await _pump(tester, territory: kUnionTerritory);

      expect(repo.localFieldCalls, [3]);
      expect(repo.unionCalls, isEmpty);
      expect(
        find.text('Elige un campo local para ver el avance de sus clubes.'),
        findsOneWidget,
      );
      expect(find.text('CAMPOS LOCALES'), findsOneWidget);
      expect(find.text('Asociación Este'), findsOneWidget);
      expect(find.text('Asociación Oeste'), findsOneWidget);
    });

    testWidgets('tapping a local field pushes union and local field ids', (
      tester,
    ) async {
      await _pump(tester, territory: kUnionTerritory);

      await tester.tap(find.text('Asociación Oeste'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'landing:/supervision/annual-progress?union_id=3&local_field_id=11',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an empty union says so', (tester) async {
      final repo = FakeProgressRepo()
        ..onLocalFields = (_) async => const Right([]);
      await _pump(tester, territory: kUnionTerritory, repo: repo);

      expect(find.text('Sin campos locales en esta unión'), findsOneWidget);
    });

    testWidgets('an error shows the error state and retry reloads', (
      tester,
    ) async {
      final repo = FakeProgressRepo();
      final ok = repo.onLocalFields;
      repo.onLocalFields = (id) async =>
          repo.localFieldCalls.length == 1 ? const Left(kBoom) : ok(id);
      await _pump(tester, territory: kUnionTerritory, repo: repo);

      expect(find.text('No se pudo cargar el progreso anual'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.localFieldCalls, hasLength(2));
      expect(find.text('Asociación Este'), findsOneWidget);
    });

    testWidgets('a 403 shows the forbidden state', (tester) async {
      final repo = FakeProgressRepo()
        ..onLocalFields = (_) async => const Left(kForbidden);
      await _pump(tester, territory: kUnionTerritory, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
    });
  });

  group('division drilled into a union', () {
    testWidgets('lists the local fields of that union, titled by its name', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        home: const SupervisionAnnualProgressView(unionId: 2),
      );

      expect(repo.localFieldCalls, [2]);
      expect(repo.unionCalls, [5]);
      // The union list one level up gives the name of the screen.
      expect(find.text('Unión Sur'), findsOneWidget);
      expect(find.text('Progreso anual'), findsOneWidget);
      expect(find.text('Asociación Este'), findsOneWidget);
    });

    testWidgets('falls back to the generic title when the name is unknown', (
      tester,
    ) async {
      final repo = FakeProgressRepo()
        ..onUnions = (_) async => const Left(kBoom);
      await _pump(
        tester,
        repo: repo,
        home: const SupervisionAnnualProgressView(unionId: 2),
      );

      expect(find.text('Progreso anual'), findsWidgets);
      expect(find.text('Asociación Este'), findsOneWidget);
    });

    testWidgets('a local field pushes both ids', (tester) async {
      await _pump(
        tester,
        home: const SupervisionAnnualProgressView(unionId: 2),
      );

      await tester.tap(find.text('Asociación Este'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'landing:/supervision/annual-progress?union_id=2&local_field_id=10',
        ),
        findsOneWidget,
      );
    });
  });

  group('no territory', () {
    testWidgets('a level that is none of the three shows the setup state', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        territory: const AuthorizationTerritory(level: 'club'),
      );

      expect(find.text('Territorio sin configurar'), findsOneWidget);
      expect(
        find.text(
          'Tu cuenta no tiene una unión o división desde la cual consultar el progreso.',
        ),
        findsOneWidget,
      );
      expect(repo.unionCalls, isEmpty);
      expect(repo.localFieldCalls, isEmpty);
    });

    testWidgets('no territory at all shows the setup state', (tester) async {
      await _pump(tester, territory: null);

      expect(find.text('Territorio sin configurar'), findsOneWidget);
    });

    testWidgets('a division level without division id shows the setup state', (
      tester,
    ) async {
      await _pump(
        tester,
        territory: const AuthorizationTerritory(level: 'division'),
      );

      expect(find.text('Territorio sin configurar'), findsOneWidget);
    });
  });

  group('clubs of a local field', () {
    testWidgets('requests the first club type and the year by default', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        types: const [kConquistadores, kAventureros],
      );

      expect(repo.progressCalls, hasLength(1));
      expect(repo.progressCalls.single, (
        localFieldId: 11,
        clubTypeId: 2,
        yearId: 7,
      ));
    });

    testWidgets('a local field user lands on their own clubs', (tester) async {
      final repo = await _pump(
        tester,
        territory: kLocalFieldTerritory,
        home: const SupervisionAnnualProgressView(),
      );

      expect(repo.progressCalls.single.localFieldId, 11);
      expect(repo.unionCalls, isEmpty);
      expect(find.text('CLUBES'), findsOneWidget);
    });

    testWidgets('titles the screen with the local field name', (tester) async {
      await _pump(tester, home: _leaf, territory: kUnionTerritory);

      expect(find.text('Asociación Oeste'), findsOneWidget);
      expect(find.text('Progreso anual'), findsOneWidget);
    });

    testWidgets('shows the year name caption', (tester) async {
      await _pump(tester, home: _leaf, territory: kUnionTerritory);

      expect(find.text('2025-2026'), findsOneWidget);
    });

    testWidgets('hides the club type chips when there is one type', (
      tester,
    ) async {
      await _pump(tester, home: _leaf, territory: kUnionTerritory);

      expect(find.byType(SacFilterChip), findsNothing);
    });

    testWidgets('shows a chip per club type, the first one selected', (
      tester,
    ) async {
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        types: const [kConquistadores, kAventureros],
      );

      expect(find.byType(SacFilterChip), findsNWidgets(2));
      expect(
        tester
            .widget<SacFilterChip>(
              find.widgetWithText(SacFilterChip, 'Conquistadores'),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<SacFilterChip>(
              find.widgetWithText(SacFilterChip, 'Aventureros'),
            )
            .selected,
        isFalse,
      );
    });

    testWidgets('picking a chip requests that club type', (tester) async {
      final repo = await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        types: const [kConquistadores, kAventureros],
      );

      await tester.tap(find.widgetWithText(SacFilterChip, 'Aventureros'));
      await tester.pumpAndSettle();

      expect(repo.progressCalls, hasLength(2));
      expect(repo.progressCalls.last, (
        localFieldId: 11,
        clubTypeId: 1,
        yearId: 7,
      ));
      expect(
        tester
            .widget<SacFilterChip>(
              find.widgetWithText(SacFilterChip, 'Aventureros'),
            )
            .selected,
        isTrue,
      );
    });

    testWidgets('rows show name, medal and points, and the percentage', (
      tester,
    ) async {
      final repo = _repoWithClubs([
        clubProgress(
          1,
          name: 'Club Orión',
          points: 320,
          max: 500,
          pct: 64,
          current: const SupervisionProgressTier(name: 'Oro'),
        ),
        clubProgress(
          2,
          name: 'Club Sin Medalla',
          points: 12.5,
          max: 500,
          pct: 2.5,
          current: null,
        ),
      ]);
      await _pump(tester, home: _leaf, territory: kUnionTerritory, repo: repo);

      expect(find.text('Club Orión'), findsOneWidget);
      expect(find.text('Oro · 320 de 500 pts'), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
      // No current medal: the points stand alone.
      expect(find.text('Club Sin Medalla'), findsOneWidget);
      expect(find.text('12.5 de 500 pts'), findsOneWidget);
      expect(find.text('2%'), findsOneWidget);
    });

    testWidgets('a blank medal name counts as no medal', (tester) async {
      final repo = _repoWithClubs([
        clubProgress(
          1,
          current: const SupervisionProgressTier(name: '  '),
        ),
      ]);
      await _pump(tester, home: _leaf, territory: kUnionTerritory, repo: repo);

      expect(find.text('320 de 500 pts'), findsOneWidget);
    });

    testWidgets('99.6 shows 99% and only a full club shows 100%', (
      tester,
    ) async {
      final repo = _repoWithClubs([
        clubProgress(1, name: 'Casi', pct: 99.6),
        clubProgress(2, name: 'Completo', pct: 100),
      ]);
      await _pump(tester, home: _leaf, territory: kUnionTerritory, repo: repo);

      expect(find.text('99%'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text('Casi'), findsOneWidget);
    });

    testWidgets('shows the skeleton while the progress loads', (tester) async {
      final gate = Completer<SupervisionAnnualProgress>();
      final repo = FakeProgressRepo()
        ..onProgress = (_) async => Right(await gate.future);
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: repo,
        settle: false,
      );

      expect(find.byType(SacSkeletonList), findsWidgets);

      gate.complete(
        SupervisionAnnualProgress(
          configured: true,
          clubs: [clubProgress(1, name: 'Club Orión')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Club Orión'), findsOneWidget);
    });

    testWidgets('a server that is not configured names the club type', (
      tester,
    ) async {
      final repo = FakeProgressRepo()
        ..onProgress = (_) async =>
            const Right(SupervisionAnnualProgress(configured: false));
      await _pump(tester, home: _leaf, territory: kUnionTerritory, repo: repo);

      expect(find.text('Aún sin configurar'), findsOneWidget);
      expect(
        find.text(
          'Este campo local todavía no configura el progreso anual de '
          'Conquistadores para este año.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the not-configured body follows the picked club type', (
      tester,
    ) async {
      final repo = FakeProgressRepo()
        ..onProgress = (_) async =>
            const Right(SupervisionAnnualProgress(configured: false));
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: repo,
        types: const [kConquistadores, kAventureros],
      );

      await tester.tap(find.widgetWithText(SacFilterChip, 'Aventureros'));
      await tester.pumpAndSettle();

      expect(
          find.textContaining('progreso anual de Aventureros'), findsOneWidget);
    });

    testWidgets('configured with no clubs shows the empty state', (
      tester,
    ) async {
      final repo = _repoWithClubs(const []);
      await _pump(tester, home: _leaf, territory: kUnionTerritory, repo: repo);

      expect(find.text('Aún no hay avance registrado'), findsOneWidget);
      expect(find.text('Aún sin configurar'), findsNothing);
    });

    testWidgets('no current year shows the no-year state', (tester) async {
      final repo = await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        noYear: true,
      );

      expect(find.text('Sin año eclesiástico en curso'), findsOneWidget);
      expect(repo.progressCalls, isEmpty);
    });

    testWidgets('an empty club type catalog shows the no-year state', (
      tester,
    ) async {
      final repo = await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        types: const [],
      );

      expect(find.text('Sin año eclesiástico en curso'), findsOneWidget);
      expect(repo.progressCalls, isEmpty);
    });

    testWidgets('a progress error shows the error state and retry reloads', (
      tester,
    ) async {
      final repo = FakeProgressRepo();
      final ok = repo.onProgress;
      repo.onProgress = (q) async =>
          repo.progressCalls.length == 1 ? const Left(kBoom) : ok(q);
      await _pump(tester, home: _leaf, territory: kUnionTerritory, repo: repo);

      expect(find.text('No se pudo cargar el progreso anual'), findsOneWidget);
      // The year caption survives: only the list failed.
      expect(find.text('2025-2026'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.progressCalls, hasLength(2));
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('a progress 403 shows the forbidden state', (tester) async {
      final repo = FakeProgressRepo()
        ..onProgress = (_) async => const Left(kForbidden);
      await _pump(tester, home: _leaf, territory: kUnionTerritory, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('club sheet', () {
    SupervisionClubProgress fullClub() => clubProgress(
          1,
          name: 'Club Orión',
          points: 320,
          max: 500,
          pct: 64,
          current: const SupervisionProgressTier(name: 'Oro'),
          next: const SupervisionProgressTier(
            name: 'Platino',
            pointsToReach: 30,
          ),
          axes: [
            axis(
              'a1',
              label: 'Eje Espiritual',
              components: [
                component('c1', label: 'Reuniones', earned: 10, max: 20),
                component('c2',
                    label: 'Estudio bíblico', earned: 5, max: 5, pct: 100),
              ],
            ),
            axis(
              'a2',
              label: 'Eje Servicio',
              components: [
                component('c3',
                    label: 'Proyectos', earned: 7.5, max: 15, pct: 40)
              ],
            ),
          ],
        );

    Future<void> openFull(WidgetTester tester) async {
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: _repoWithClubs([fullClub()]),
      );
      await _openClub(tester, 'Club Orión');
    }

    testWidgets('opens with the club name and club type as header', (
      tester,
    ) async {
      await openFull(tester);

      expect(_sheet(), findsOneWidget);
      expect(_inSheet(find.text('Club Orión')), findsOneWidget);
      expect(_inSheet(find.text('Conquistadores')), findsOneWidget);
    });

    testWidgets('summary lists progress, points, medal and next medal', (
      tester,
    ) async {
      await openFull(tester);

      expect(_inSheet(find.text('RESUMEN')), findsOneWidget);
      expect(_inSheet(find.text('Avance')), findsOneWidget);
      expect(_inSheet(find.text('64%')), findsOneWidget);
      expect(_inSheet(find.text('Puntos')), findsOneWidget);
      expect(_inSheet(find.text('320 de 500 pts')), findsOneWidget);
      expect(_inSheet(find.text('Medalla actual')), findsOneWidget);
      expect(_inSheet(find.text('Oro')), findsOneWidget);
      expect(_inSheet(find.text('Siguiente medalla')), findsOneWidget);
      expect(_inSheet(find.text('Platino · faltan 30 pts')), findsOneWidget);
    });

    testWidgets('shows one group per axis with its components', (tester) async {
      await openFull(tester);

      expect(_inSheet(find.text('EJE ESPIRITUAL')), findsOneWidget);
      expect(_inSheet(find.text('EJE SERVICIO')), findsOneWidget);
      expect(_inSheet(find.text('Reuniones')), findsOneWidget);
      expect(_inSheet(find.text('10 de 20 pts')), findsOneWidget);
      expect(_inSheet(find.text('50%')), findsOneWidget);
      expect(_inSheet(find.text('Estudio bíblico')), findsOneWidget);
      expect(_inSheet(find.text('5 de 5 pts')), findsOneWidget);
      expect(_inSheet(find.text('100%')), findsOneWidget);
      expect(_inSheet(find.text('Proyectos')), findsOneWidget);
      expect(_inSheet(find.text('7.5 de 15 pts')), findsOneWidget);
      expect(_inSheet(find.text('40%')), findsOneWidget);
      expect(_inSheet(find.text('DE DÓNDE VIENEN LOS PUNTOS')), findsNothing);
    });

    testWidgets('without axes the components go in one flat group', (
      tester,
    ) async {
      final club = clubProgress(
        1,
        name: 'Club Orión',
        components: [
          component('c1', label: 'Reuniones'),
          component('c2', label: 'Proyectos'),
        ],
      );
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: _repoWithClubs([club]),
      );
      await _openClub(tester, 'Club Orión');

      expect(_inSheet(find.text('DE DÓNDE VIENEN LOS PUNTOS')), findsOneWidget);
      expect(_inSheet(find.text('Reuniones')), findsOneWidget);
      expect(_inSheet(find.text('Proyectos')), findsOneWidget);
    });

    testWidgets('axes without components fall back to the flat group', (
      tester,
    ) async {
      final club = clubProgress(
        1,
        name: 'Club Orión',
        axes: [axis('a1', label: 'Eje Vacío')],
        components: [component('c1', label: 'Reuniones')],
      );
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: _repoWithClubs([club]),
      );
      await _openClub(tester, 'Club Orión');

      expect(_inSheet(find.text('EJE VACÍO')), findsNothing);
      expect(_inSheet(find.text('DE DÓNDE VIENEN LOS PUNTOS')), findsOneWidget);
    });

    testWidgets('without a current medal it says there is none yet', (
      tester,
    ) async {
      final club = clubProgress(1, name: 'Club Orión', current: null);
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: _repoWithClubs([club]),
      );
      await _openClub(tester, 'Club Orión');

      expect(_inSheet(find.text('Sin medalla aún')), findsOneWidget);
      expect(_inSheet(find.text('Siguiente medalla')), findsNothing);
    });

    testWidgets('without a next medal the row is hidden', (tester) async {
      final club = clubProgress(1, name: 'Club Orión', next: null);
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: _repoWithClubs([club]),
      );
      await _openClub(tester, 'Club Orión');

      expect(_inSheet(find.text('Medalla actual')), findsOneWidget);
      expect(_inSheet(find.text('Siguiente medalla')), findsNothing);
    });

    testWidgets('a next medal with no points to reach shows only its name', (
      tester,
    ) async {
      final club = clubProgress(
        1,
        name: 'Club Orión',
        next: const SupervisionProgressTier(name: 'Platino'),
      );
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: _repoWithClubs([club]),
      );
      await _openClub(tester, 'Club Orión');

      expect(_inSheet(find.text('Platino')), findsOneWidget);
      expect(_inSheet(find.textContaining('faltan')), findsNothing);
    });

    testWidgets('dismissing the sheet returns to the list', (tester) async {
      await openFull(tester);

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(_sheet(), findsNothing);
      expect(find.text('Club Orión'), findsOneWidget);
    });
  });

  group('wording', () {
    testWidgets('never shows the word ranking or a position number', (
      tester,
    ) async {
      final club = clubProgress(
        1,
        name: 'Club Orión',
        next: const SupervisionProgressTier(name: 'Platino', pointsToReach: 30),
        axes: [
          axis('a1', label: 'Eje Espiritual', components: [component('c1')]),
        ],
      );
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        types: const [kConquistadores, kAventureros],
        repo: _repoWithClubs([club, clubProgress(2, name: 'Club Dos')]),
      );

      final ranking =
          find.textContaining(RegExp('ranking', caseSensitive: false));
      final position = find.textContaining(RegExp(r'(^|\s)#\d|\d+(º|°|\.º)'));
      expect(ranking, findsNothing);
      expect(position, findsNothing);

      await _openClub(tester, 'Club Orión');
      expect(_sheet(), findsOneWidget);
      expect(ranking, findsNothing);
      expect(position, findsNothing);
    });

    testWidgets('the territory lists never say ranking either', (tester) async {
      await _pump(tester);

      expect(
        find.textContaining(RegExp('ranking', caseSensitive: false)),
        findsNothing,
      );
    });
  });

  group('layout at 320x640 with text scale 2.0', () {
    List<SupervisionTerritoryOption> longOptions() => [
          for (var i = 1; i <= 4; i++) territoryOption(i, '$_longName $i'),
        ];

    testWidgets('unions list does not overflow', (tester) async {
      final repo = FakeProgressRepo()
        ..onUnions = (_) async => Right(longOptions());
      await _pump(tester, repo: repo, size: _narrow, textScale: 2.0);

      expect(find.textContaining('Asociación de Clubes'), findsWidgets);
      expectNoException(tester);
    });

    testWidgets('local fields list does not overflow', (tester) async {
      final repo = FakeProgressRepo()
        ..onLocalFields = (_) async => Right(longOptions());
      await _pump(
        tester,
        territory: kUnionTerritory,
        repo: repo,
        size: _narrow,
        textScale: 2.0,
      );

      expectNoException(tester);
    });

    testWidgets('a long union name in the title does not overflow', (
      tester,
    ) async {
      final repo = FakeProgressRepo()
        ..onUnions = (_) async => Right(longOptions());
      await _pump(
        tester,
        repo: repo,
        home: const SupervisionAnnualProgressView(unionId: 2),
        size: _narrow,
        textScale: 2.0,
      );

      expectNoException(tester);
    });

    testWidgets('empty, error and no-territory states do not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        territory: const AuthorizationTerritory(level: 'club'),
        size: _narrow,
        textScale: 2.0,
      );

      expect(find.text('Territorio sin configurar'), findsOneWidget);
      expectNoException(tester);
    });

    FakeProgressRepo longClubsRepo({String Function(int) nameOf = _longClub}) =>
        _repoWithClubs([
          for (var i = 1; i <= 3; i++)
            clubProgress(
              i,
              name: nameOf(i),
              points: 123456.5,
              max: 987654,
              pct: 99.6,
              current: const SupervisionProgressTier(
                name: 'Medalla de Oro con Honores Especiales',
              ),
              next: const SupervisionProgressTier(
                name: 'Medalla de Platino con Honores Especiales',
                pointsToReach: 98765.5,
              ),
              axes: [
                axis(
                  'a1',
                  label: 'Eje de Vida Espiritual y Devocional del Club',
                  components: [
                    component(
                      'c1',
                      label: 'Participación en reuniones semanales de oración',
                      earned: 123456.5,
                      max: 987654,
                    ),
                    component('c2', label: 'Estudio'),
                  ],
                ),
              ],
            ),
        ]);

    testWidgets('leaf with chips and long clubs does not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        types: const [kConquistadores, kAventureros],
        repo: longClubsRepo(),
        size: _narrow,
        textScale: 2.0,
      );

      expectNoException(tester);
      await tester.scrollUntilVisible(
        find.text(_longClub(1)),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expectNoException(tester);
    });

    testWidgets('leaf not-configured and empty states do not overflow', (
      tester,
    ) async {
      final repo = FakeProgressRepo()
        ..onProgress = (_) async =>
            const Right(SupervisionAnnualProgress(configured: false));
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: repo,
        types: const [kConquistadores, kAventureros],
        size: _narrow,
        textScale: 2.0,
      );

      expect(find.text('Aún sin configurar'), findsOneWidget);
      expectNoException(tester);
    });

    testWidgets('club sheet with a 72-char club name does not overflow',
        (tester) async {
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: longClubsRepo(),
        size: _narrow,
        textScale: 2.0,
      );
      await tester.scrollUntilVisible(
        find.text(_longClub(1)),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // scrollUntilVisible stops at the edge: bring it clear of the top bar.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 140));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_longClub(1)));
      await tester.pumpAndSettle();

      expect(_sheet(), findsOneWidget);
      expectNoException(tester);

      // Scroll the whole sheet: every group must lay out.
      await tester.drag(
          _inSheet(find.byType(SingleChildScrollView)), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expectNoException(tester);
    });

    testWidgets(
        'club sheet with a 63-char club name and long axes does not overflow',
        (tester) async {
      await _pump(
        tester,
        home: _leaf,
        territory: kUnionTerritory,
        repo: longClubsRepo(nameOf: _mediumClub),
        size: _narrow,
        textScale: 2.0,
      );
      await tester.scrollUntilVisible(
        find.text(_mediumClub(1)),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      // scrollUntilVisible stops at the edge: bring it clear of the top bar.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 140));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_mediumClub(1)));
      await tester.pumpAndSettle();

      expect(_sheet(), findsOneWidget);
      expectNoException(tester);

      // Scroll the whole sheet: every group must lay out.
      await tester.drag(
          _inSheet(find.byType(SingleChildScrollView)), const Offset(0, -1500));
      await tester.pumpAndSettle();
      expectNoException(tester);
    });
  });
}
