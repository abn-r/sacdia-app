/// Widget tests for the approvals queue of one union camporee: kind chips,
/// cards, the item sheet and the approve / reject flows.
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_camporee_approvals_view.dart';

import 'supervision_camporee_test_harness.dart';
import 'supervision_view_test_harness.dart';

const _shortSurface = Size(800, 900);
const _narrow = Size(320, 640);
const _sheetMarker = 'DETALLE';
const _genericError = 'Ocurrió un error. Inténtalo de nuevo.';

SupervisionCamporeePending _pending({
  List<SupervisionCamporeePendingClub> clubs = const [],
  List<SupervisionCamporeePendingMember> members = const [],
  List<SupervisionCamporeePendingPayment> payments = const [],
}) =>
    SupervisionCamporeePending(
      clubs: clubs,
      members: members,
      payments: payments,
    );

/// A repository that serves [pending] and, on a successful decision, drops
/// the decided item from it (what the server does).
FakeCamporeesRepo _repoWith(SupervisionCamporeePending pending) {
  var current = pending;
  final repo = FakeCamporeesRepo();
  repo.onPending = (_) async => Right(current);
  repo.onDecide = (d) async {
    current = SupervisionCamporeePending(
      clubs: current.clubs
          .where((c) => d.kind != DecisionKind.club || '${c.id}' != d.id)
          .toList(),
      members: current.members
          .where((m) => d.kind != DecisionKind.member || '${m.id}' != d.id)
          .toList(),
      payments: current.payments
          .where((p) => d.kind != DecisionKind.payment || p.id != d.id)
          .toList(),
    );
    return const Right(unit);
  };
  return repo;
}

Future<CamporeeEnv> _pump(
  WidgetTester tester, {
  FakeCamporeesRepo? repo,
  String camporeeId = '5',
  List<String> capabilities = const [
    kSupervisionAppView,
    kApproveRegistrationsCap,
  ],
  Size? size,
  double? textScale,
  bool settle = true,
}) =>
    pumpCamporeeView(
      tester,
      home: SupervisionCamporeeApprovalsView(camporeeId: camporeeId),
      repo: repo,
      capabilities: capabilities,
      size: size,
      textScale: textScale,
      settle: settle,
    );

String _date(DateTime when) => intl.DateFormat.yMMMd('es').format(when);

Finder _chip(String label) => find.widgetWithText(SacFilterChip, label);

Finder _button(String text) => find.widgetWithText(SacButton, text);

Finder _row(String label, String value) => find.byWidgetPredicate(
      (w) => w is SacValueRow && w.label == label && w.value == value,
    );

Finder _rowLabel(String label) =>
    find.byWidgetPredicate((w) => w is SacValueRow && w.label == label);

final _sheetOpen = find.text(_sheetMarker);

Future<void> _openSheet(WidgetTester tester, String title) async {
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

/// Taps "Aprobar" in the sheet and confirms the dialog.
Future<void> _approve(WidgetTester tester) async {
  await tester.tap(_button('Aprobar'));
  await tester.pumpAndSettle();
  // The dialog repeats the label: its action sits on top.
  await tester.tap(find.text('Aprobar').last);
  await tester.pumpAndSettle();
}

/// Taps "Rechazar" in the sheet, writes [reason] and confirms.
Future<void> _reject(WidgetTester tester, String reason) async {
  await tester.tap(_button('Rechazar'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), reason);
  await tester.pump();
  await tester.tap(_button('Rechazar').last);
  await tester.pumpAndSettle();
}

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

  group('invalid id', () {
    testWidgets('a non-numeric id shows the error state and calls nothing', (
      tester,
    ) async {
      final repo = FakeCamporeesRepo();
      await _pump(tester, repo: repo, camporeeId: 'abc');

      expect(
          find.text('No se pudieron cargar las aprobaciones'), findsOneWidget);
      expect(find.text('Revisa tu conexión e inténtalo de nuevo.'),
          findsOneWidget);
      expect(find.text('Reintentar'), findsNothing);
      expect(repo.pendingCalls, isEmpty);
      expect(repo.camporeeCalls, isEmpty);
    });
  });

  group('loading and states', () {
    testWidgets('shows the skeleton, then the queue', (tester) async {
      final gate = Completer<CamporeePendingResult>();
      final repo = FakeCamporeesRepo()..onPending = ((_) => gate.future);
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);

      gate.complete(Right(_pending(clubs: [pendingClub(1)])));
      await tester.pumpAndSettle();

      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('requests the pending list of the camporee in the path', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      await _pump(tester, repo: repo, camporeeId: '42');

      expect(repo.pendingCalls, [42]);
      expect(repo.camporeeCalls, [42]);
    });

    testWidgets('the camporee name is the top bar subtitle', (tester) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onCamporee =
            ((id) async => Right(camporee(id, name: 'Camporee Norte')));
      await _pump(tester, repo: repo);

      expect(find.text('Por aprobar'), findsOneWidget);
      expect(find.text('Camporee Norte'), findsOneWidget);
    });

    testWidgets('a failed camporee name does not break the queue', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onCamporee = ((_) async => const Left(kCamporeeBoom));
      await _pump(tester, repo: repo);

      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('everything empty shows «Nada espera aprobación»', (
      tester,
    ) async {
      await _pump(tester, repo: _repoWith(_pending()));

      expect(find.text('Nada espera aprobación'), findsOneWidget);
      expect(
        find.text(
          'Las inscripciones y los pagos fuera de plazo aparecen aquí para '
          'que los revises.',
        ),
        findsOneWidget,
      );
      expect(find.byType(SacFilterChip), findsNothing);
    });

    testWidgets('a load error shows retry and retrying reloads', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      final served = repo.onPending;
      var fail = true;
      repo.onPending =
          (id) async => fail ? const Left(kCamporeeBoom) : served(id);
      await _pump(tester, repo: repo);

      expect(
          find.text('No se pudieron cargar las aprobaciones'), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);

      fail = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.pendingCalls, hasLength(2));
      expect(find.text('No se pudieron cargar las aprobaciones'), findsNothing);
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = FakeCamporeesRepo()
        ..onPending = ((_) async => const Left(kCamporeeForbidden));
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudieron cargar las aprobaciones'), findsNothing);
      expect(find.text('Reintentar'), findsNothing);
    });

    testWidgets('pull to refresh reloads the queue and the hub counts', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      final env = await _pump(tester, repo: repo, size: _shortSurface);
      expect(repo.pendingCalls, hasLength(1));
      expect(env.countsCalls, 1);

      await _pullToRefresh(tester, find.text('Club 1'));

      expect(repo.pendingCalls, hasLength(2));
      expect(env.countsCalls, 2);
      expect(find.text('Club 1'), findsOneWidget);
    });
  });

  group('kind chips', () {
    testWidgets('carry the count of each kind, none when 0', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            clubs: [pendingClub(1), pendingClub(2)],
            members: [pendingMember(1)],
          ),
        ),
      );

      expect(_chip('Clubes · 2'), findsOneWidget);
      expect(_chip('Miembros · 1'), findsOneWidget);
      expect(_chip('Pagos'), findsOneWidget);
      expect(find.textContaining('Pagos ·'), findsNothing);
    });

    testWidgets('opens on clubs when clubs wait', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            clubs: [pendingClub(1)],
            members: [pendingMember(1)],
            payments: [pendingPayment('p1')],
          ),
        ),
      );

      expect(
          tester.widget<SacFilterChip>(_chip('Clubes · 1')).selected, isTrue);
      expect(find.text('Club 1'), findsOneWidget);
      expect(find.text('Miembro 1'), findsNothing);
      expect(find.text('Pagador p1'), findsNothing);
    });

    testWidgets('opens on members when there are no clubs', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            members: [pendingMember(1)],
            payments: [pendingPayment('p1')],
          ),
        ),
      );

      expect(
          tester.widget<SacFilterChip>(_chip('Miembros · 1')).selected, isTrue);
      expect(find.text('Miembro 1'), findsOneWidget);
    });

    testWidgets('opens on payments when only payments wait', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(payments: [pendingPayment('p1')])),
      );

      expect(tester.widget<SacFilterChip>(_chip('Pagos · 1')).selected, isTrue);
      expect(find.text('Pagador p1'), findsOneWidget);
    });

    testWidgets('switching chips swaps the cards', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            clubs: [pendingClub(1)],
            members: [pendingMember(1)],
            payments: [pendingPayment('p1')],
          ),
        ),
      );

      await tester.tap(_chip('Miembros · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Miembro 1'), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);
      expect(
          tester.widget<SacFilterChip>(_chip('Miembros · 1')).selected, isTrue);

      await tester.tap(_chip('Pagos · 1'));
      await tester.pumpAndSettle();
      expect(find.text('Pagador p1'), findsOneWidget);
      expect(find.text('Miembro 1'), findsNothing);
    });

    testWidgets('a kind with nothing shows «Nada por aprobar aquí»', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(clubs: [pendingClub(1)])),
      );

      await tester.tap(_chip('Pagos'));
      await tester.pumpAndSettle();

      expect(find.text('Nada por aprobar aquí'), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);
      // The chips stay so the reviewer can go back.
      expect(_chip('Clubes · 1'), findsOneWidget);
    });
  });

  group('cards', () {
    testWidgets('a club card shows name, section and who registered it', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            clubs: [
              pendingClub(
                1,
                name: 'Club Orión',
                section: 'Aventureros',
                registeredBy: 'Elena Ruiz',
              ),
            ],
          ),
        ),
      );

      expect(find.text('Club Orión'), findsOneWidget);
      expect(find.text('Aventureros'), findsOneWidget);
      expect(find.text('Registró: Elena Ruiz'), findsOneWidget);
    });

    testWidgets('a club card without registrant has no "Registró" line', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(clubs: [pendingClub(1, registeredBy: null)])),
      );

      expect(find.textContaining('Registró'), findsNothing);
    });

    testWidgets('an unnamed club falls back to «Club sin nombre»', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(clubs: [pendingClub(1, name: '  ')])),
      );

      expect(find.text('Club sin nombre'), findsOneWidget);
    });

    testWidgets('a member card shows name, club and insurance', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            members: [
              pendingMember(1, name: 'Ana Pérez', club: 'Club Orión'),
              pendingMember(2, name: 'Luis Gómez', insured: false),
            ],
          ),
        ),
      );

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('Club Orión'), findsNWidgets(2));
      expect(find.text('Seguro verificado'), findsOneWidget);
      expect(find.text('Luis Gómez'), findsOneWidget);
      expect(find.text('Seguro sin verificar'), findsOneWidget);
    });

    testWidgets('an unnamed member falls back to «Miembro sin nombre»', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(members: [pendingMember(1, name: '')])),
      );

      expect(find.text('Miembro sin nombre'), findsOneWidget);
    });

    testWidgets('a payment card shows member, club, amount and type', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            payments: [
              pendingPayment(
                'p1',
                member: 'Ana Pérez',
                club: 'Club Orión',
                amount: 350,
              ),
              pendingPayment(
                'p2',
                member: 'Luis Gómez',
                amount: 1250.5,
                type: SupervisionCamporeePaymentType.materials,
              ),
              pendingPayment(
                'p3',
                member: 'Rosa Díaz',
                amount: 10,
                type: SupervisionCamporeePaymentType.unknown,
              ),
            ],
          ),
        ),
      );

      expect(find.text('Ana Pérez'), findsOneWidget);
      expect(find.text('\$350.00 · Inscripción'), findsOneWidget);
      expect(find.text('\$1,250.50 · Materiales'), findsOneWidget);
      // Anything the app does not know is "Otro".
      expect(find.text('\$10.00 · Otro'), findsOneWidget);
    });
  });

  group('item sheet', () {
    testWidgets('a club sheet shows its subtitle and facts', (tester) async {
      final created = DateTime(2026, 11, 3, 10);
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            clubs: [
              pendingClub(
                1,
                name: 'Club Orión',
                section: 'Aventureros',
                registeredBy: 'Elena Ruiz',
                createdAt: created,
              ),
            ],
          ),
        ),
      );
      await _openSheet(tester, 'Club Orión');

      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Inscripción de club'), findsOneWidget);
      expect(_row('Sección', 'Aventureros'), findsOneWidget);
      expect(_row('Registró', 'Elena Ruiz'), findsOneWidget);
      expect(_row('Fecha de registro', _date(created)), findsOneWidget);
    });

    testWidgets('a member sheet shows its subtitle and facts', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            members: [pendingMember(1, name: 'Luis Gómez', insured: false)],
          ),
        ),
      );
      await _openSheet(tester, 'Luis Gómez');

      expect(find.text('Inscripción de miembro'), findsOneWidget);
      expect(_row('Club', 'Club Orión'), findsOneWidget);
      expect(_row('Seguro', 'Seguro sin verificar'), findsOneWidget);
    });

    testWidgets('a payment sheet shows every fact it has', (tester) async {
      final paid = DateTime(2026, 11, 10);
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            payments: [
              pendingPayment(
                'p1',
                member: 'Ana Pérez',
                amount: 350,
                reference: 'REF-123',
                notes: 'Pago en dos partes',
                paidAt: paid,
              ),
            ],
          ),
        ),
      );
      await _openSheet(tester, 'Ana Pérez');

      expect(find.text('Pago'), findsOneWidget);
      expect(_row('Monto', '\$350.00'), findsOneWidget);
      expect(_row('Tipo', 'Inscripción'), findsOneWidget);
      expect(_row('Club', 'Club Orión'), findsOneWidget);
      expect(_row('Referencia', 'REF-123'), findsOneWidget);
      expect(_row('Fecha de pago', _date(paid)), findsOneWidget);
      expect(_row('Notas', 'Pago en dos partes'), findsOneWidget);
    });

    testWidgets('a payment sheet omits notes, reference and date when absent', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(payments: [pendingPayment('p1', member: 'Ana Pérez')]),
        ),
      );
      await _openSheet(tester, 'Ana Pérez');

      expect(_rowLabel('Monto'), findsOneWidget);
      expect(_rowLabel('Notas'), findsNothing);
      expect(_rowLabel('Referencia'), findsNothing);
      expect(_rowLabel('Fecha de pago'), findsNothing);
    });

    testWidgets('a blank note is not shown', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            payments: [pendingPayment('p1', member: 'Ana Pérez', notes: '  ')],
          ),
        ),
      );
      await _openSheet(tester, 'Ana Pérez');

      expect(_rowLabel('Notas'), findsNothing);
    });

    testWidgets('«Ver comprobante» shows only with a voucher URL', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(
            payments: [
              pendingPayment(
                'p1',
                member: 'Con Voucher',
                voucherUrl: 'https://example.com/v.png',
              ),
              pendingPayment('p2', member: 'Sin Voucher'),
              pendingPayment('p3', member: 'Voucher Vacío', voucherUrl: '  '),
            ],
          ),
        ),
      );

      await _openSheet(tester, 'Con Voucher');
      expect(find.text('Ver comprobante'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await _openSheet(tester, 'Sin Voucher');
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Ver comprobante'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      await _openSheet(tester, 'Voucher Vacío');
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Ver comprobante'), findsNothing);
    });

    testWidgets('without the approve capability there are no buttons', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(clubs: [pendingClub(1)])),
        capabilities: const [kSupervisionAppView],
      );
      await _openSheet(tester, 'Club 1');

      expect(_sheetOpen, findsOneWidget);
      expect(_button('Aprobar'), findsNothing);
      expect(_button('Rechazar'), findsNothing);
    });

    testWidgets('with the capability both buttons are enabled', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(clubs: [pendingClub(1)])),
      );
      await _openSheet(tester, 'Club 1');

      expect(tester.widget<SacButton>(_button('Aprobar')).isEnabled, isTrue);
      expect(tester.widget<SacButton>(_button('Rechazar')).isEnabled, isTrue);
    });
  });

  group('approve', () {
    testWidgets('the confirm dialog names the club', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(clubs: [pendingClub(1, name: 'Club Orión')])),
      );
      await _openSheet(tester, 'Club Orión');

      await tester.tap(_button('Aprobar'));
      await tester.pumpAndSettle();

      expect(
          find.text('¿Aprobar la inscripción de Club Orión?'), findsOneWidget);
      expect(
        find.text(
          'Queda inscrito en el camporee y cuenta para el cobro y la agenda.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the confirm dialog of a payment names the payer', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(payments: [pendingPayment('p1', member: 'Ana Pérez')]),
        ),
      );
      await _openSheet(tester, 'Ana Pérez');

      await tester.tap(_button('Aprobar'));
      await tester.pumpAndSettle();

      expect(find.text('¿Aprobar el pago de Ana Pérez?'), findsOneWidget);
    });

    testWidgets('cancelling the dialog calls nothing and keeps the sheet', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_button('Aprobar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.decisions, isEmpty);
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Inscripción aprobada'), findsNothing);
    });

    testWidgets('a club is approved with its ids, toasts and closes the sheet',
        (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(11)]));
      await _pump(tester, repo: repo, camporeeId: '5');
      await _openSheet(tester, 'Club 11');

      await _approve(tester);

      expect(repo.decisions, hasLength(1));
      final d = repo.decisions.single;
      expect(d.kind, DecisionKind.club);
      expect(d.camporeeId, 5);
      expect(d.id, '11');
      expect(d.approve, isTrue);
      expect(d.reason, isNull);
      expect(find.text('Inscripción aprobada'), findsOneWidget);
      expect(_sheetOpen, findsNothing);
    });

    testWidgets('a member is approved through the member endpoint', (
      tester,
    ) async {
      final repo = _repoWith(_pending(members: [pendingMember(21)]));
      await _pump(tester, repo: repo, camporeeId: '5');
      await _openSheet(tester, 'Miembro 21');

      await tester.tap(_button('Aprobar'));
      await tester.pumpAndSettle();
      expect(
          find.text('¿Aprobar la inscripción de Miembro 21?'), findsOneWidget);
      await tester.tap(find.text('Aprobar').last);
      await tester.pumpAndSettle();

      final d = repo.decisions.single;
      expect(d.kind, DecisionKind.member);
      expect(d.camporeeId, 5);
      expect(d.id, '21');
      expect(d.approve, isTrue);
      expect(find.text('Inscripción aprobada'), findsOneWidget);
      expect(_sheetOpen, findsNothing);
    });

    testWidgets('a payment is approved by its UUID and toasts «Pago aprobado»',
        (
      tester,
    ) async {
      final repo = _repoWith(
        _pending(payments: [pendingPayment('uuid-1', member: 'Ana Pérez')]),
      );
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Ana Pérez');

      await _approve(tester);

      final d = repo.decisions.single;
      expect(d.kind, DecisionKind.payment);
      expect(d.id, 'uuid-1');
      expect(d.approve, isTrue);
      expect(find.text('Pago aprobado'), findsOneWidget);
      expect(_sheetOpen, findsNothing);
    });

    testWidgets('the decided item leaves the queue and the lists reload', (
      tester,
    ) async {
      final repo = _repoWith(
        _pending(clubs: [pendingClub(1), pendingClub(2)]),
      );
      final env = await _pump(tester, repo: repo);
      expect(repo.pendingCalls, hasLength(1));
      expect(env.countsCalls, 1);

      await _openSheet(tester, 'Club 1');
      await _approve(tester);

      expect(repo.pendingCalls, hasLength(2));
      // The hub counts are stale too.
      expect(env.countsCalls, 2);
      expect(find.text('Club 1'), findsNothing);
      expect(find.text('Club 2'), findsOneWidget);
      expect(_chip('Clubes · 1'), findsOneWidget);
    });

    testWidgets('deciding the last item shows the empty state', (tester) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);

      expect(find.text('Nada espera aprobación'), findsOneWidget);
    });

    testWidgets('while in flight the buttons cannot fire a second request', (
      tester,
    ) async {
      final gate = Completer<Either<Failure, Unit>>();
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onDecide = ((_) => gate.future);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_button('Aprobar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Aprobar').last);
      // Not settled: the loading button never stops animating.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(repo.decisions, hasLength(1));
      expect(tester.widget<SacButton>(_button('Aprobar')).isEnabled, isFalse);
      expect(tester.widget<SacButton>(_button('Aprobar')).isLoading, isTrue);
      expect(tester.widget<SacButton>(_button('Rechazar')).isEnabled, isFalse);

      await tester.tap(_button('Aprobar'), warnIfMissed: false);
      await tester.tap(_button('Rechazar'), warnIfMissed: false);
      await tester.pump();
      await tester.pump();
      expect(repo.decisions, hasLength(1));
      expect(find.text('Rechazar la inscripción de Club 1'), findsNothing);

      gate.complete(const Right(unit));
      await tester.pumpAndSettle();
      expect(repo.decisions, hasLength(1));
      expect(_sheetOpen, findsNothing);
    });
  });

  group('reject', () {
    testWidgets('the decision sheet names what is rejected', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(_pending(clubs: [pendingClub(1, name: 'Club Orión')])),
      );
      await _openSheet(tester, 'Club Orión');

      await tester.tap(_button('Rechazar'));
      await tester.pumpAndSettle();

      expect(
          find.text('Rechazar la inscripción de Club Orión'), findsOneWidget);
      expect(
        find.text(
          'Se avisa del rechazo y el motivo queda en la auditoría.',
        ),
        findsOneWidget,
      );
      expect(find.text('Motivo'), findsOneWidget);
    });

    testWidgets('a payment uses its own reject title', (tester) async {
      await _pump(
        tester,
        repo: _repoWith(
          _pending(payments: [pendingPayment('p1', member: 'Ana Pérez')]),
        ),
      );
      await _openSheet(tester, 'Ana Pérez');

      await tester.tap(_button('Rechazar'));
      await tester.pumpAndSettle();

      expect(find.text('Rechazar el pago de Ana Pérez'), findsOneWidget);
    });

    testWidgets('an empty reason shows the required text and sends nothing', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_button('Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Rechazar').last);
      await tester.pumpAndSettle();

      expect(find.text('Escribe el motivo.'), findsOneWidget);
      expect(repo.decisions, isEmpty);
    });

    testWidgets('a reason shorter than 5 characters sends nothing', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _reject(tester, '  abcd  ');

      expect(find.text('Escribe al menos 5 caracteres.'), findsOneWidget);
      expect(repo.decisions, isEmpty);
      expect(_sheetOpen, findsOneWidget);
    });

    testWidgets('a valid reason is sent trimmed with approve false', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _reject(tester, '   Documentos incompletos  ');

      final d = repo.decisions.single;
      expect(d.kind, DecisionKind.club);
      expect(d.approve, isFalse);
      expect(d.reason, 'Documentos incompletos');
      expect(find.text('Inscripción rechazada'), findsOneWidget);
      expect(_sheetOpen, findsNothing);
    });

    testWidgets('exactly 5 characters are enough', (tester) async {
      final repo = _repoWith(_pending(members: [pendingMember(3)]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Miembro 3');

      await _reject(tester, 'Falta');

      final d = repo.decisions.single;
      expect(d.kind, DecisionKind.member);
      expect(d.id, '3');
      expect(d.approve, isFalse);
      expect(d.reason, 'Falta');
      expect(find.text('Inscripción rechazada'), findsOneWidget);
    });

    testWidgets('a payment is rejected and toasts «Pago rechazado»', (
      tester,
    ) async {
      final repo = _repoWith(
        _pending(payments: [pendingPayment('uuid-9', member: 'Ana Pérez')]),
      );
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Ana Pérez');

      await _reject(tester, 'Comprobante ilegible');

      final d = repo.decisions.single;
      expect(d.kind, DecisionKind.payment);
      expect(d.id, 'uuid-9');
      expect(d.approve, isFalse);
      expect(d.reason, 'Comprobante ilegible');
      expect(find.text('Pago rechazado'), findsOneWidget);
      expect(_sheetOpen, findsNothing);
    });

    testWidgets('cancelling the decision sheet sends nothing', (tester) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_button('Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(_button('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.decisions, isEmpty);
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Inscripción rechazada'), findsNothing);
    });
  });

  group('failures', () {
    for (final entry in {
      DecisionKind.club: 'CAMPOREE_CLUB_ENROLLMENT_PENDING_NOT_FOUND',
      DecisionKind.member: 'CAMPOREE_MEMBER_ENROLLMENT_PENDING_NOT_FOUND',
      DecisionKind.payment: 'CAMPOREE_PAYMENT_PENDING_NOT_FOUND',
    }.entries) {
      testWidgets(
          '${entry.value} closes the sheet with «Alguien más ya lo resolvió.» '
          'and reloads', (tester) async {
        final repo = _repoWith(
          _pending(
            clubs: [pendingClub(1, name: 'Item')],
            members: [pendingMember(1, name: 'Item')],
            payments: [pendingPayment('p1', member: 'Item')],
          ),
        );
        // The first load serves every kind; later loads, an empty queue.
        var loads = 0;
        final served = repo.onPending;
        repo.onPending = (id) {
          loads++;
          return loads == 1
              ? served(id)
              : Future.value(Right(_pending(payments: [
                  pendingPayment('other', member: 'Otra persona'),
                ])));
        };
        repo.onDecide = (_) async => Left(coded(entry.value));
        await _pump(tester, repo: repo);
        await tester.tap(_chip(switch (entry.key) {
          DecisionKind.club => 'Clubes · 1',
          DecisionKind.member => 'Miembros · 1',
          DecisionKind.payment => 'Pagos · 1',
        }));
        await tester.pumpAndSettle();
        await _openSheet(tester, 'Item');

        await _approve(tester);

        expect(repo.decisions, hasLength(1));
        expect(_sheetOpen, findsNothing);
        expect(find.text('Alguien más ya lo resolvió.'), findsOneWidget);
        expect(repo.pendingCalls, hasLength(2));
      });
    }

    testWidgets('any *_PENDING_NOT_FOUND code closes the sheet', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onDecide = ((_) async => Left(coded('SOMETHING_PENDING_NOT_FOUND')));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);

      expect(_sheetOpen, findsNothing);
      expect(find.text('Alguien más ya lo resolvió.'), findsOneWidget);
    });

    testWidgets(
        'CAMPOREE_CLUB_REGISTRATION_CLOSED keeps the sheet open with inline '
        'text', (tester) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onDecide =
            ((_) async => Left(coded('CAMPOREE_CLUB_REGISTRATION_CLOSED')));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);

      expect(_sheetOpen, findsOneWidget);
      expect(
        find.textContaining(
          'La inscripción de clubes de este camporee está cerrada',
        ),
        findsOneWidget,
      );
      expect(find.text('server says no'), findsNothing);
      expect(tester.widget<SacButton>(_button('Aprobar')).isEnabled, isTrue);
    });

    testWidgets('a 403 shows the inline permission text', (tester) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onDecide = ((_) async => const Left(kCamporeeForbidden));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);

      expect(_sheetOpen, findsOneWidget);
      expect(
        find.text('No tienes permiso para hacer esto en este camporee.'),
        findsOneWidget,
      );
      expect(find.text('nope'), findsNothing);
    });

    testWidgets('another failure shows the server message inline', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onDecide = ((_) async => Left(coded('SOMETHING_ELSE')));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);

      expect(find.text('server says no'), findsOneWidget);
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Inscripción aprobada'), findsNothing);
    });

    testWidgets('a blank server message shows the generic error', (
      tester,
    ) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onDecide = ((_) async => const Left(ServerFailure(message: '  ')));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);

      expect(find.text(_genericError), findsOneWidget);
      expect(_sheetOpen, findsOneWidget);
    });

    testWidgets('a failed rejection shows the error and keeps the reason flow',
        (
      tester,
    ) async {
      final repo = _repoWith(_pending(payments: [pendingPayment('p1')]))
        ..onDecide = ((_) async => const Left(kCamporeeBoom));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Pagador p1');

      await _reject(tester, 'Comprobante ilegible');

      expect(find.text('boom'), findsOneWidget);
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Pago rechazado'), findsNothing);
      expect(tester.widget<SacButton>(_button('Rechazar')).isEnabled, isTrue);
    });

    testWidgets('the inline error clears on the next attempt', (tester) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]));
      final decide = repo.onDecide;
      var fail = true;
      repo.onDecide =
          (d) async => fail ? Left(coded('SOMETHING_ELSE')) : decide(d);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);
      expect(find.text('server says no'), findsOneWidget);

      fail = false;
      await _approve(tester);

      expect(find.text('server says no'), findsNothing);
      expect(_sheetOpen, findsNothing);
      expect(find.text('Inscripción aprobada'), findsOneWidget);
    });

    testWidgets('a plain failure does not reload the queue', (tester) async {
      final repo = _repoWith(_pending(clubs: [pendingClub(1)]))
        ..onDecide = ((_) async => Left(coded('SOMETHING_ELSE')));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approve(tester);

      expect(repo.pendingCalls, hasLength(1));
    });
  });

  group('layout robustness', () {
    // Distinct 70-character strings, so each can be found on its own.
    String long(String seed) => '$seed Conquistadores del Distrito Central de '
            'la Asociación Metropolitana Norte'
        .substring(0, 70);
    final clubName = long('Club');
    final memberName = long('Miembro');
    final payerName = long('Pagador');

    SupervisionCamporeePending longPending() => _pending(
          clubs: [
            pendingClub(
              1,
              name: clubName,
              section: long('Sección'),
              registeredBy: long('Registró'),
            ),
          ],
          members: [pendingMember(1, name: memberName, club: long('Club M'))],
          payments: [
            pendingPayment(
              'p1',
              member: payerName,
              club: long('Club P'),
              reference: long('Ref'),
              notes: '${long('Nota')} ${long('Nota')}',
              paidAt: DateTime(2026, 11, 10),
              voucherUrl: 'https://example.com/v.png',
            ),
          ],
        );

    /// The chip row is a lazy horizontal list: scroll it to the chip.
    Future<void> tapChip(WidgetTester tester, String label) async {
      await tester.scrollUntilVisible(
        _chip(label),
        80,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axis == Axis.horizontal,
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(_chip(label));
      await tester.pumpAndSettle();
    }

    for (final scale in [1.0, 2.0]) {
      group('text scale $scale', () {
        testWidgets('320x640: club queue does not overflow', (tester) async {
          expect(clubName, hasLength(70));
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );

          expectNoLayoutException(tester);
          expect(find.text(clubName), findsOneWidget);
        });

        testWidgets('320x640: member queue does not overflow', (tester) async {
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );
          await tapChip(tester, 'Miembros · 1');

          expectNoLayoutException(tester);
          expect(find.text(memberName), findsOneWidget);
        });

        testWidgets('320x640: payment queue does not overflow', (tester) async {
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );
          await tapChip(tester, 'Pagos · 1');

          expectNoLayoutException(tester);
          expect(find.text(payerName), findsOneWidget);
        });

        testWidgets('320x640: club sheet does not overflow', (tester) async {
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );
          await _openSheet(tester, clubName);

          expectNoLayoutException(tester);
          expect(_sheetOpen, findsOneWidget);
        });

        testWidgets('320x640: member sheet does not overflow', (tester) async {
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );
          await tapChip(tester, 'Miembros · 1');
          await _openSheet(tester, memberName);

          expectNoLayoutException(tester);
          expect(_sheetOpen, findsOneWidget);
        });

        testWidgets('320x640: payment sheet does not overflow', (tester) async {
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );
          await tapChip(tester, 'Pagos · 1');
          await _openSheet(tester, payerName);

          expectNoLayoutException(tester);
          expect(_sheetOpen, findsOneWidget);
        });

        testWidgets('320x640: reject decision sheet does not overflow', (
          tester,
        ) async {
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );
          await _openSheet(tester, clubName);
          await tester.tap(_button('Rechazar'));
          await tester.pumpAndSettle();

          expectNoLayoutException(tester);
          expect(find.text('Motivo'), findsOneWidget);
        });

        testWidgets('320x640: approve dialog does not overflow',
            (tester) async {
          await _pump(
            tester,
            repo: _repoWith(longPending()),
            size: _narrow,
            textScale: scale,
          );
          await _openSheet(tester, clubName);
          await tester.tap(_button('Aprobar'));
          await tester.pumpAndSettle();

          expectNoLayoutException(tester);
          expect(find.textContaining('¿Aprobar la inscripción de'),
              findsOneWidget);
        });
      });
    }

    testWidgets('320x640, text scale 2.0: error state does not overflow', (
      tester,
    ) async {
      final repo = FakeCamporeesRepo()
        ..onPending = ((_) async => const Left(kCamporeeBoom));
      await _pump(tester, repo: repo, size: _narrow, textScale: 2.0);

      expectNoLayoutException(tester);
    });

    testWidgets('320x640, text scale 2.0: empty state does not overflow', (
      tester,
    ) async {
      await _pump(
        tester,
        repo: _repoWith(_pending()),
        size: _narrow,
        textScale: 2.0,
      );

      expectNoLayoutException(tester);
    });
  });
}
