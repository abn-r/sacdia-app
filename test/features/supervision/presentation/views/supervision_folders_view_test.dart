/// Widget tests for the territorial annual-folder queue.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_folders_view.dart';

import 'supervision_folders_test_harness.dart';
import 'supervision_view_test_harness.dart';

Future<FakeFoldersRepo> _pump(
  WidgetTester tester, {
  FakeFoldersRepo? repo,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? FakeFoldersRepo();
  await pumpFoldersApp(
    tester,
    home: const SupervisionFoldersView(),
    repo: fake,
    size: size,
    textScale: textScale,
    settle: settle,
  );
  return fake;
}

Finder _chip(String label) => find.widgetWithText(SacFilterChip, label);

void main() {
  setUpAll(initSupervisionViewTests);

  group('load states', () {
    testWidgets('shows the skeleton while the first page loads', (
      tester,
    ) async {
      final gate = Completer<QueueResult>();
      final repo = FakeFoldersRepo()..onQueue = (_) => gate.future;
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.byType(SacEmptyState), findsNothing);
      expect(find.byType(SacErrorState), findsNothing);

      gate.complete(Right(queuePage([queueItem('1')])));
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Carpeta 1'), findsOneWidget);
    });

    testWidgets('shows the error state and retry reloads the queue', (
      tester,
    ) async {
      final repo = FakeFoldersRepo();
      repo.onQueue = (_) async => repo.queueCalls.length == 1
          ? const Left(kBoom)
          : Right(queuePage([queueItem('1')]));
      await _pump(tester, repo: repo);

      expect(find.text('No se pudieron cargar las carpetas'), findsOneWidget);
      expect(find.byType(ForbiddenView), findsNothing);
      expect(find.text('Carpeta 1'), findsNothing);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls, hasLength(2));
      expect(find.text('No se pudieron cargar las carpetas'), findsNothing);
      expect(find.text('Carpeta 1'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue =
            (_) async => const Left(AuthFailure(message: 'nope', code: 403));
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudieron cargar las carpetas'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('empty "Por revisar" shows its own title', (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage(const []));
      await _pump(tester, repo: repo);

      expect(find.text('Nada por revisar'), findsOneWidget);
      expect(
          find.textContaining('Las carpetas de tu territorio'), findsOneWidget);
    });

    testWidgets('empty title changes with the filter', (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage(const []));
      await _pump(tester, repo: repo);

      await tester.tap(_chip('Evaluadas'));
      await tester.pumpAndSettle();
      expect(find.text('Sin carpetas evaluadas'), findsOneWidget);
      expect(find.text('Nada por revisar'), findsNothing);

      await tester.tap(_chip('Todas'));
      await tester.pumpAndSettle();
      expect(find.text('Sin carpetas'), findsOneWidget);
      expect(find.text('Sin carpetas evaluadas'), findsNothing);
    });
  });

  group('cards', () {
    testWidgets('title is the display name, with type and field line', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem(
                '1',
                displayName: 'Orión 2026',
                clubName: 'Club Orión',
              ),
            ]));
      await _pump(tester, repo: repo);

      expect(find.text('Orión 2026'), findsOneWidget);
      expect(find.text('Club Orión'), findsNothing);
      expect(find.text('Conquistadores · Asociación Norte'), findsOneWidget);
    });

    testWidgets(
        'title falls back to the club name when the display name is '
        'blank', (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem('1', displayName: '  ', clubName: 'Club Orión'),
            ]));
      await _pump(tester, repo: repo);

      expect(find.text('Club Orión'), findsOneWidget);
    });

    testWidgets(
        'place line skips a blank part and disappears when both are '
        'blank', (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem('1', localFieldName: ''),
              queueItem('2', clubTypeName: '', localFieldName: ''),
            ]));
      await _pump(tester, repo: repo);

      expect(find.text('Conquistadores'), findsOneWidget);
      expect(find.textContaining(' · '), findsNothing);
    });

    testWidgets('lists the pending section names when there are any', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem('1', pending: const ['Tesorería', 'Secretaría']),
            ]));
      await _pump(tester, repo: repo);

      expect(find.text('Por revisar: Tesorería, Secretaría'), findsOneWidget);
      // The folder status is only the fallback.
      expect(find.text('Enviada'), findsNothing);
    });

    testWidgets('shows the folder status when no section is pending', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem('1', status: SupervisionFolderStatus.evaluated),
              queueItem('2', status: SupervisionFolderStatus.closed),
            ]));
      await _pump(tester, repo: repo);

      expect(find.text('Evaluada'), findsOneWidget);
      expect(find.text('Cerrada'), findsOneWidget);
      expect(find.textContaining('Por revisar:'), findsNothing);
    });
  });

  group('filters', () {
    testWidgets('starts on "Por revisar" and asks the server for it', (
      tester,
    ) async {
      final repo = await _pump(tester);

      expect(repo.queueCalls, hasLength(1));
      expect(repo.queueCalls.single.filter,
          SupervisionFolderQueueFilter.needsReview);
      expect(
          tester.widget<SacFilterChip>(_chip('Por revisar')).selected, isTrue);
    });

    testWidgets('tapping a chip selects it and replaces the list', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (call) async => Right(queuePage([
              queueItem(call.filter == SupervisionFolderQueueFilter.evaluated
                  ? 'evaluada'
                  : 'pendiente'),
            ]));
      await _pump(tester, repo: repo);
      expect(find.text('Carpeta pendiente'), findsOneWidget);

      await tester.tap(_chip('Evaluadas'));
      await tester.pumpAndSettle();

      expect(
          repo.queueCalls.last.filter, SupervisionFolderQueueFilter.evaluated);
      expect(repo.queueCalls.last.page, 1);
      expect(tester.widget<SacFilterChip>(_chip('Evaluadas')).selected, isTrue);
      expect(
          tester.widget<SacFilterChip>(_chip('Por revisar')).selected, isFalse);
      expect(find.text('Carpeta evaluada'), findsOneWidget);
      expect(find.text('Carpeta pendiente'), findsNothing);
    });

    testWidgets('tapping the selected chip does not refetch', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(_chip('Por revisar'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls, hasLength(1));
    });

    testWidgets('"Todas" requests the all filter', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(_chip('Todas'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls.last.filter, SupervisionFolderQueueFilter.all);
    });
  });

  group('paging', () {
    testWidgets('a short first page asks for the next one on its own', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (call) async => call.page == 1
            ? Right(queuePage(
                [queueItem('a'), queueItem('b')],
                total: 3,
              ))
            : Right(queuePage([queueItem('c')], page: 2, total: 3));
      await _pump(tester, repo: repo);

      expect(repo.queueCalls.map((c) => c.page), [1, 2]);
      expect(find.text('Carpeta a'), findsOneWidget);
      expect(find.text('Carpeta b'), findsOneWidget);
      expect(find.text('Carpeta c'), findsOneWidget);
    });

    testWidgets('a complete queue never asks for another page', (tester) async {
      final repo = await _pump(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(repo.queueCalls, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a failed page shows the footer error and does not loop', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (call) async => call.page == 1
            ? Right(queuePage([queueItem('a'), queueItem('b')], total: 3))
            : const Left(kBoom);
      await _pump(tester, repo: repo);

      expect(find.text('No se pudieron cargar más carpetas.'), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
      // The loaded items stay.
      expect(find.text('Carpeta a'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      expect(repo.queueCalls.map((c) => c.page), [1, 2]);
    });

    testWidgets('retry in the footer loads the failed page', (tester) async {
      var failNext = true;
      final repo = FakeFoldersRepo()
        ..onQueue = (call) async {
          if (call.page == 1) {
            return Right(queuePage([queueItem('a'), queueItem('b')], total: 3));
          }
          if (failNext) {
            failNext = false;
            return const Left(kBoom);
          }
          return Right(queuePage([queueItem('c')], page: 2, total: 3));
        };
      await _pump(tester, repo: repo);

      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls.map((c) => c.page), [1, 2, 2]);
      expect(find.text('No se pudieron cargar más carpetas.'), findsNothing);
      expect(find.text('Carpeta c'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('tapping a card pushes the folder detail route', (
      tester,
    ) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem('a'),
              queueItem('f-42', displayName: 'Orión 2026'),
            ]));
      await _pump(tester, repo: repo);

      await tester.tap(find.text('Orión 2026'));
      await tester.pumpAndSettle();

      expect(find.text('detail:f-42'), findsOneWidget);
    });
  });

  group('layout robustness', () {
    final longItems = [
      queueItem(
        '1',
        displayName: 'Club Estrella de la Mañana del Valle Grande de Occidente',
        clubTypeName: 'Guías Mayores de la Asociación',
        localFieldName: 'Asociación del Pacífico Norte y Centro',
        pending: const [
          'Tesorería y finanzas del club',
          'Secretaría y actas',
          'Actividades misioneras',
        ],
      ),
      queueItem('2', status: SupervisionFolderStatus.underEvaluation),
    ];

    testWidgets('320 wide at text scale 2.0 does not overflow', (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage(longItems));
      await _pump(
        tester,
        repo: repo,
        size: const Size(320, 2600),
        textScale: 2.0,
      );

      expectNoLayoutException(tester);
      expect(find.textContaining('Club Estrella'), findsOneWidget);
    });

    // With a submission date the title row also carries the relative time
    // ("hace 3 días"), which does not flex. At scale 2.0 under the Ahem font
    // (every glyph one em wide) that row overflows by 33 px on a 320 wide
    // surface (supervision_folders_view.dart:224); real fonts fit, so only
    // scale 1.0 is asserted here.
    testWidgets(
        '320 wide with a relative time in the title row does not '
        'overflow', (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem(
                '1',
                displayName: 'Club Estrella de la Mañana del Valle Grande',
                latestSubmittedAt:
                    DateTime.now().subtract(const Duration(days: 3)),
              ),
            ]));
      await _pump(tester, repo: repo, size: const Size(320, 2600));

      expectNoLayoutException(tester);
      expect(find.textContaining('Club Estrella'), findsOneWidget);
    });

    // The relative time in the title row (supervision_folders_view.dart:239)
    // does not flex: at 320 wide and scale 2.0 under Ahem the Row overflows by
    // 33 px. Real fonts probably fit ("hace 3 días"), but the title is left
    // with no width as soon as the time text grows.
    testWidgets(
        '320 wide at text scale 2.0 with a relative time does not overflow',
        (tester) async {
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem(
                '1',
                displayName: 'Club Estrella de la Mañana del Valle Grande',
                latestSubmittedAt:
                    DateTime.now().subtract(const Duration(days: 3)),
              ),
            ]));
      await _pump(
        tester,
        repo: repo,
        size: const Size(320, 2600),
        textScale: 2.0,
      );

      expectNoLayoutException(tester);
    });

    testWidgets(
        '320 wide at text scale 2.0 in the error state does not '
        'overflow', (tester) async {
      final repo = FakeFoldersRepo()..onQueue = (_) async => const Left(kBoom);
      await _pump(
        tester,
        repo: repo,
        size: const Size(320, 2600),
        textScale: 2.0,
      );

      expectNoLayoutException(tester);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('each card is one button labelled with its title', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = FakeFoldersRepo()
        ..onQueue = (_) async => Right(queuePage([
              queueItem('1', displayName: 'Orión 2026'),
              queueItem('2', displayName: 'Andrómeda 2026'),
            ]));
      await _pump(tester, repo: repo);

      for (final title in ['Orión 2026', 'Andrómeda 2026']) {
        final finder = find.bySemanticsLabel(RegExp(RegExp.escape(title)));
        expect(finder, findsOneWidget, reason: title);
        final data = tester.getSemantics(finder);
        expect(data.flagsCollection.isButton, isTrue, reason: title);
        expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: title);
      }
      handle.dispose();
    });
  });
}
