/// Widget tests for the union camporee list: one block per camporee with the
/// rows the actor may use (approvals, orders) and their status lines.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_union_camporees_view.dart';

import 'supervision_camporee_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _shortSurface = Size(800, 900);

Future<CamporeeEnv> _pump(
  WidgetTester tester, {
  FakeCamporeesRepo? repo,
  List<String> capabilities = const [
    kSupervisionAppView,
    kApproveRegistrationsCap,
    kConfigureOfferingCap,
  ],
  Size? size,
  double? textScale,
  bool settle = true,
}) =>
    pumpCamporeeView(
      tester,
      home: const SupervisionUnionCamporeesView(),
      repo: repo,
      capabilities: capabilities,
      size: size,
      textScale: textScale,
      settle: settle,
    );

FakeCamporeesRepo _repoWith(
  List<SupervisionUnionCamporee> items, {
  SupervisionCamporeePending pending = SupervisionCamporeePending.empty,
}) =>
    FakeCamporeesRepo()
      ..onList = (() async => Right(items))
      ..onPending = ((_) async => Right(pending));

String _date(DateTime when) => intl.DateFormat.yMMMd('es').format(when);

final _approvalsRow = find.text('Inscripciones y pagos');
final _ordersRow = find.text('Pedidos e insumos');

/// Flings the list down from [onItem] past the trigger distance of the
/// RefreshIndicator and lets the refresh finish.
Future<void> _pullToRefresh(WidgetTester tester, Finder onItem) async {
  await tester.fling(onItem, const Offset(0, 400), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initSupervisionViewTests);

  group('loading', () {
    testWidgets('shows the skeleton while the list loads, then the blocks', (
      tester,
    ) async {
      final gate = Completer<CamporeeList>();
      final repo = FakeCamporeesRepo()..onList = (() => gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.text('Camporee 1'), findsNothing);

      gate.complete(Right([camporee(1)]));
      await tester.pumpAndSettle();

      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Camporee 1'), findsOneWidget);
    });
  });

  group('camporee blocks', () {
    testWidgets('shows one block per camporee with its name', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([camporee(1, name: 'Camporee Norte'), camporee(2)]),
      );

      expect(find.text('Camporee de unión'), findsOneWidget);
      expect(find.text('Camporee Norte'), findsOneWidget);
      expect(find.text('Camporee 2'), findsOneWidget);
      expect(_approvalsRow, findsNWidgets(2));
      expect(_ordersRow, findsNWidgets(2));
    });

    testWidgets('shows "date range · place" when both are set', (tester) async {
      final start = DateTime(2026, 11, 12);
      final end = DateTime(2026, 11, 15);
      await _pump(
        tester,
        repo: _repoWith(
            [camporee(1, start: start, end: end, place: 'Montemorelos')]),
      );

      expect(
        find.text('${_date(start)} – ${_date(end)} · Montemorelos'),
        findsOneWidget,
      );
    });

    testWidgets('shows a single date when start and end are the same day', (
      tester,
    ) async {
      final day = DateTime(2026, 11, 12);
      await _pump(
        tester,
        repo: _repoWith([camporee(1, start: day, end: day, place: 'Sede')]),
      );

      expect(find.text('${_date(day)} · Sede'), findsOneWidget);
      expect(find.textContaining('–'), findsNothing);
    });

    testWidgets('shows only the dates when the place is blank', (tester) async {
      final start = DateTime(2026, 11, 12);
      final end = DateTime(2026, 11, 15);
      await _pump(
        tester,
        repo: _repoWith([camporee(1, start: start, end: end, place: '   ')]),
      );

      expect(find.text('${_date(start)} – ${_date(end)}'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('shows only the place when there are no dates', (tester) async {
      await _pump(tester, repo: _repoWith([camporee(1, place: 'Sede')]));

      expect(find.text('Sede'), findsOneWidget);
    });

    testWidgets('shows no "where" line when neither dates nor place exist', (
      tester,
    ) async {
      await _pump(tester, repo: _repoWith([camporee(1)]));

      expect(find.textContaining('·'), findsNothing);
      expect(find.text('Camporee 1'), findsOneWidget);
    });
  });

  group('capabilities', () {
    testWidgets('both rows with both capabilities', (tester) async {
      await _pump(tester, repo: _repoWith([camporee(1)]));

      expect(_approvalsRow, findsOneWidget);
      expect(_ordersRow, findsOneWidget);
    });

    testWidgets('only approvals with approve_registrations', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([camporee(1)]),
        capabilities: const [kSupervisionAppView, kApproveRegistrationsCap],
      );

      expect(_approvalsRow, findsOneWidget);
      expect(_ordersRow, findsNothing);
    });

    testWidgets('only orders with configure_offering', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([camporee(1)]),
        capabilities: const [kSupervisionAppView, kConfigureOfferingCap],
      );

      expect(_approvalsRow, findsNothing);
      expect(_ordersRow, findsOneWidget);
    });

    testWidgets('no rows without either capability, name still shown', (
      tester,
    ) async {
      final repo = _repoWith([camporee(1)]);
      await _pump(
        tester,
        repo: repo,
        capabilities: const [kSupervisionAppView],
      );

      expect(_approvalsRow, findsNothing);
      expect(_ordersRow, findsNothing);
      expect(find.text('Camporee 1'), findsOneWidget);
      // Nothing to count: the pending request is never made.
      expect(repo.pendingCalls, isEmpty);
    });
  });

  group('approvals row status', () {
    testWidgets('shows the pending total when something waits', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          [camporee(1)],
          pending: SupervisionCamporeePending(
            clubs: [pendingClub(1), pendingClub(2)],
            members: [pendingMember(1)],
            payments: [pendingPayment('p1')],
          ),
        ),
      );

      expect(find.text('4 por aprobar'), findsOneWidget);
      expect(find.text('Al día'), findsNothing);
    });

    testWidgets('shows "Al día" when nothing waits', (tester) async {
      await _pump(tester, repo: _repoWith([camporee(1)]));

      expect(find.text('Al día'), findsOneWidget);
    });

    testWidgets('counts each camporee on its own', (tester) async {
      final repo = FakeCamporeesRepo()
        ..onList = (() async => Right([camporee(1), camporee(2)]))
        ..onPending = ((id) async => Right(
              id == 1
                  ? SupervisionCamporeePending(clubs: [pendingClub(1)])
                  : SupervisionCamporeePending.empty,
            ));
      await _pump(tester, repo: repo);

      expect(find.text('1 por aprobar'), findsOneWidget);
      expect(find.text('Al día'), findsOneWidget);
      expect(repo.pendingCalls.toSet(), {1, 2});
    });

    testWidgets('shows the description while the count loads', (tester) async {
      final gate = Completer<CamporeePendingResult>();
      final repo = FakeCamporeesRepo()
        ..onList = (() async => Right([camporee(1)]))
        ..onPending = ((_) => gate.future);
      await _pump(tester, repo: repo, settle: false);
      await tester.pump();

      expect(
        find.text('Clubes, miembros y pagos fuera de plazo'),
        findsOneWidget,
      );
      expect(find.text('Al día'), findsNothing);

      gate.complete(const Right(SupervisionCamporeePending.empty));
      await tester.pumpAndSettle();
      expect(find.text('Al día'), findsOneWidget);
    });

    testWidgets('keeps the description when the pending request fails', (
      tester,
    ) async {
      final repo = FakeCamporeesRepo()
        ..onList = (() async => Right([camporee(1)]))
        ..onPending = ((_) async => const Left(kCamporeeBoom));
      await _pump(tester, repo: repo);

      expect(
        find.text('Clubes, miembros y pagos fuera de plazo'),
        findsOneWidget,
      );
      expect(find.text('Al día'), findsNothing);
      // The failed count does not take the block down.
      expect(find.text('Camporee 1'), findsOneWidget);
      expect(_ordersRow, findsOneWidget);
    });
  });

  group('orders row status', () {
    testWidgets('disabled orders', (tester) async {
      await _pump(tester, repo: _repoWith([camporee(1)]));

      expect(find.text('Pedidos deshabilitados'), findsOneWidget);
    });

    testWidgets('enabled without dates reads "Pedidos abiertos"', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([camporee(1, ordersEnabled: true)]),
      );

      expect(find.text('Pedidos abiertos'), findsOneWidget);
    });

    testWidgets('opening in the future shows the opening date', (tester) async {
      final opens = DateTime.now().add(const Duration(days: 30));
      await _pump(
        tester,
        repo: _repoWith([camporee(1, ordersEnabled: true, opensAt: opens)]),
      );

      expect(
        find.text('Los pedidos abren el ${_date(opens.toLocal())}'),
        findsOneWidget,
      );
    });

    testWidgets('a deadline in the past reads "Pedidos cerrados"', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([
          camporee(
            1,
            ordersEnabled: true,
            opensAt: DateTime.now().subtract(const Duration(days: 20)),
            deadline: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ]),
      );

      expect(find.text('Pedidos cerrados'), findsOneWidget);
    });

    testWidgets('an opened window with a future deadline is "abiertos"', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith([
          camporee(
            1,
            ordersEnabled: true,
            opensAt: DateTime.now().subtract(const Duration(days: 2)),
            deadline: DateTime.now().add(const Duration(days: 2)),
          ),
        ]),
      );

      expect(find.text('Pedidos abiertos'), findsOneWidget);
    });

    testWidgets('disabled wins over dates in the past', (tester) async {
      await _pump(
        tester,
        repo: _repoWith([
          camporee(
            1,
            deadline: DateTime.now().subtract(const Duration(days: 1)),
          ),
        ]),
      );

      expect(find.text('Pedidos deshabilitados'), findsOneWidget);
      expect(find.text('Pedidos cerrados'), findsNothing);
    });
  });

  group('navigation', () {
    testWidgets('tapping approvals pushes the approvals route', (tester) async {
      await _pump(tester, repo: _repoWith([camporee(7)]));

      await tester.tap(_approvalsRow);
      await tester.pumpAndSettle();

      expect(find.text('approvals:7'), findsOneWidget);
    });

    testWidgets('tapping orders pushes the orders route', (tester) async {
      await _pump(tester, repo: _repoWith([camporee(7)]));

      await tester.tap(_ordersRow);
      await tester.pumpAndSettle();

      expect(find.text('orders:7'), findsOneWidget);
    });

    testWidgets('each block pushes its own camporee id', (tester) async {
      await _pump(tester, repo: _repoWith([camporee(7), camporee(9)]));

      await tester.tap(_approvalsRow.last);
      await tester.pumpAndSettle();

      expect(find.text('approvals:9'), findsOneWidget);
    });
  });

  group('empty and error states', () {
    testWidgets('an empty list shows «Sin camporees de unión»', (tester) async {
      await _pump(tester, repo: _repoWith(const []));

      expect(find.text('Sin camporees de unión'), findsOneWidget);
      expect(
        find.text('Cuando tu unión tenga un camporee activo lo verás aquí.'),
        findsOneWidget,
      );
    });

    testWidgets('an error shows retry and retrying reloads the list', (
      tester,
    ) async {
      final repo = _repoWith([camporee(1)]);
      var fail = true;
      repo.onList =
          () async => fail ? const Left(kCamporeeBoom) : Right([camporee(1)]);
      await _pump(tester, repo: repo);

      expect(find.text('No se pudieron cargar los camporees'), findsOneWidget);
      expect(find.text('Revisa tu conexión e inténtalo de nuevo.'),
          findsOneWidget);
      expect(find.text('Camporee 1'), findsNothing);

      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.listCalls, 2);
      expect(find.text('No se pudieron cargar los camporees'), findsNothing);
      expect(find.text('Camporee 1'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = FakeCamporeesRepo()
        ..onList = (() async => const Left(kCamporeeForbidden));
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudieron cargar los camporees'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('pull to refresh', () {
    testWidgets('reloads the list and the pending counts', (tester) async {
      final repo = _repoWith(
        [camporee(1), camporee(2)],
      );
      await _pump(tester, repo: repo, size: _shortSurface);
      expect(repo.listCalls, 1);
      expect(repo.pendingCalls.where((id) => id == 1), hasLength(1));
      expect(repo.pendingCalls.where((id) => id == 2), hasLength(1));

      await _pullToRefresh(tester, find.text('Camporee 1'));

      expect(repo.listCalls, 2);
      expect(repo.pendingCalls.where((id) => id == 1), hasLength(2));
      expect(repo.pendingCalls.where((id) => id == 2), hasLength(2));
      expect(find.text('Camporee 1'), findsOneWidget);
    });

    testWidgets('picks up a changed pending count', (tester) async {
      var total = 1;
      final repo = FakeCamporeesRepo()
        ..onList = (() async => Right([camporee(1)]))
        ..onPending = ((_) async => Right(
              SupervisionCamporeePending(
                clubs: [for (var i = 0; i < total; i++) pendingClub(i + 1)],
              ),
            ));
      await _pump(tester, repo: repo, size: _shortSurface);
      expect(find.text('1 por aprobar'), findsOneWidget);

      total = 3;
      await _pullToRefresh(tester, find.text('Camporee 1'));

      expect(find.text('3 por aprobar'), findsOneWidget);
    });

    testWidgets('a failed refresh keeps the last list on screen', (
      tester,
    ) async {
      final repo = _repoWith([camporee(1)]);
      await _pump(tester, repo: repo, size: _shortSurface);

      repo.onList = () async => const Left(kCamporeeBoom);
      await _pullToRefresh(tester, find.text('Camporee 1'));

      expect(repo.listCalls, 2);
      expect(find.text('Camporee 1'), findsOneWidget);
      expect(find.text('No se pudieron cargar los camporees'), findsNothing);
    });
  });

  group('layout robustness', () {
    const narrow = Size(320, 640);
    // 70 characters of words, so it can wrap.
    final longName = 'Camporee de Unión Regional Conquistadores Aventureros '
            'Guías Mayores 2026'
        .padRight(70, 'x')
        .substring(0, 70);
    final longPlace = 'Campamento Nacional de la Asociación Central Mexicana '
            'Montemorelos'
        .padRight(70, 'y')
        .substring(0, 70);

    for (final scale in [1.0, 2.0]) {
      testWidgets('320x640, text scale $scale: blocks do not overflow', (
        tester,
      ) async {
        expect(longName, hasLength(70));
        expect(longPlace, hasLength(70));
        final repo = _repoWith(
          [
            camporee(
              1,
              name: longName,
              start: DateTime(2026, 11, 12),
              end: DateTime(2026, 11, 15),
              place: longPlace,
              ordersEnabled: true,
              opensAt: DateTime.now().add(const Duration(days: 30)),
            ),
          ],
          pending: SupervisionCamporeePending(clubs: [pendingClub(1)]),
        );
        await _pump(tester, repo: repo, size: narrow, textScale: scale);

        expectNoLayoutException(tester);
        expect(find.text(longName), findsOneWidget);
      });
    }

    testWidgets('320x640, text scale 2.0: error state does not overflow', (
      tester,
    ) async {
      final repo = FakeCamporeesRepo()
        ..onList = (() async => const Left(kCamporeeBoom));
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);

      expectNoLayoutException(tester);
    });

    testWidgets('320x640, text scale 2.0: empty state does not overflow', (
      tester,
    ) async {
      await _pump(tester,
          repo: _repoWith(const []), size: narrow, textScale: 2.0);

      expectNoLayoutException(tester);
    });
  });
}
