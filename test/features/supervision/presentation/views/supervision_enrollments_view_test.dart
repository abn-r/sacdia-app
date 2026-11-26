/// Widget tests for the territorial club-enrollment queue and its decision
/// sheets (approve dialog, rejection reason sheet).
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_enrollment.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_enrollments_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_enrollments_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_enrollments_view.dart';

import 'supervision_view_test_harness.dart';

typedef _QueueResult = Either<Failure, SupervisionEnrollmentPage>;
typedef _ItemResult = Either<Failure, SupervisionEnrollment>;

const _pending = SupervisionEnrollmentStatus.pendingValidation;
const _active = SupervisionEnrollmentStatus.active;
const _rejected = SupervisionEnrollmentStatus.rejected;

const _validatorCaps = [kSupervisionAppView, kValidateCap];

SupervisionEnrollment _enr(
  String id, {
  SupervisionEnrollmentStatus status = _pending,
  String clubTypeName = 'Conquistadores',
  String localFieldName = 'Asociación Norte',
  String yearName = '2026',
  String? address,
  String? meetingDays,
  int? soulsTarget,
  bool hasFee = false,
  double? feeAmount,
  SupervisionEnrollmentBoard board = const SupervisionEnrollmentBoard(),
  SupervisionPersonRef? submittedBy,
  DateTime? submittedAt,
  SupervisionPersonRef? reviewedBy,
  DateTime? reviewedAt,
  String? decisionReason,
}) =>
    SupervisionEnrollment(
      id: id,
      status: status,
      yearName: yearName,
      clubName: 'Club $id',
      clubTypeName: clubTypeName,
      localFieldName: localFieldName,
      address: address,
      meetingDays: meetingDays,
      soulsTarget: soulsTarget,
      hasFee: hasFee,
      feeAmount: feeAmount,
      board: board,
      submittedBy: submittedBy,
      submittedAt: submittedAt,
      reviewedBy: reviewedBy,
      reviewedAt: reviewedAt,
      decisionReason: decisionReason,
    );

SupervisionEnrollmentPage _page(
  List<SupervisionEnrollment> items, {
  int page = 1,
  int? total,
  SupervisionEnrollmentCounts counts = const SupervisionEnrollmentCounts(
    pending: 5,
    approved: 2,
    rejected: 1,
  ),
}) =>
    SupervisionEnrollmentPage(
      items: items,
      page: page,
      total: total ?? items.length,
      counts: counts,
    );

const _boom = ServerFailure(message: 'boom');

ServerFailure _coded(String code, [String message = 'server says no']) =>
    ServerFailure(message: message, errorCode: code);

class _QueueCall {
  _QueueCall(this.status, this.page);
  final SupervisionEnrollmentStatus status;
  final int page;
}

class _FakeRepo implements SupervisionEnrollmentsRepository {
  final queueCalls = <_QueueCall>[];
  final approved = <String>[];
  final rejected = <({String id, String reason})>[];

  Future<_QueueResult> Function(_QueueCall call) onQueue =
      (_) async => Right(_page([_enr('1')]));
  Future<_ItemResult> Function(String id)? onApprove;
  Future<_ItemResult> Function(String id, String reason)? onReject;

  @override
  Future<_QueueResult> getQueue({
    SupervisionEnrollmentStatus status = _pending,
    String? search,
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) {
    final call = _QueueCall(status, page);
    queueCalls.add(call);
    return onQueue(call);
  }

  @override
  Future<_ItemResult> approve(
    String enrollmentId, {
    RequestCancelToken? cancelToken,
  }) {
    approved.add(enrollmentId);
    return (onApprove ??
        (id) async => Right(_enr(id, status: _active)))(enrollmentId);
  }

  @override
  Future<_ItemResult> reject(
    String enrollmentId,
    String reason, {
    RequestCancelToken? cancelToken,
  }) {
    rejected.add((id: enrollmentId, reason: reason));
    return (onReject ?? (id, _) async => Right(_enr(id, status: _rejected)))(
      enrollmentId,
      reason,
    );
  }
}

Future<_FakeRepo> _pump(
  WidgetTester tester, {
  _FakeRepo? repo,
  List<String> capabilities = _validatorCaps,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final fake = repo ?? _FakeRepo();
  await pumpSupervisionView(
    tester,
    home: const SupervisionEnrollmentsView(),
    user: supervisionUser(capabilities: capabilities),
    size: size,
    textScale: textScale,
    settle: settle,
    overrides: [
      supervisionEnrollmentsRepositoryProvider.overrideWithValue(fake),
      supervisionPendingCountsProvider.overrideWith(
        (ref) async => const SupervisionPendingCounts(territoryLevel: 'union'),
      ),
    ],
  );
  return fake;
}

Finder _chip(String label) => find.widgetWithText(SacFilterChip, label);

int? _chipCount(WidgetTester tester, String label) =>
    tester.widget<SacFilterChip>(_chip(label)).count;

/// Opens the sheet of the enrollment card titled [clubName].
Future<void> _openSheet(WidgetTester tester, String clubName) async {
  await tester.tap(find.text(clubName));
  await tester.pumpAndSettle();
}

/// Marker of the enrollment sheet (the "operation" group always renders).
final _sheetOpen = find.text('FUNCIONAMIENTO');

Finder _row(String label, String value) => find.byWidgetPredicate(
      (w) => w is SacValueRow && w.label == label && w.value == value,
    );

Finder _rowLabel(String label) =>
    find.byWidgetPredicate((w) => w is SacValueRow && w.label == label);

Finder _barButton(String text) => find.widgetWithText(SacButton, text);

Finder _dialogButton(String text) => find.descendant(
      of: find.byType(SacDialog),
      matching: find.widgetWithText(SacButton, text),
    );

/// The confirm button of the decision sheet is the last "Rechazar" in the
/// tree (the action bar of the enrollment sheet sits below it).
Finder get _decisionConfirm => _barButton('Rechazar').last;

Future<void> _approveThroughDialog(WidgetTester tester) async {
  await tester.tap(_barButton('Aprobar'));
  await tester.pumpAndSettle();
  await tester.tap(_dialogButton('Aprobar'));
  await tester.pumpAndSettle();
}

Future<void> _rejectWith(WidgetTester tester, String text) async {
  await tester.tap(_barButton('Rechazar'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField), text);
  await tester.pump();
  await tester.tap(_decisionConfirm);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(initSupervisionViewTests);

  group('load states', () {
    testWidgets('shows the skeleton while the first page loads', (
      tester,
    ) async {
      final gate = Completer<_QueueResult>();
      final repo = _FakeRepo()..onQueue = (_) => gate.future;
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);
      expect(find.byType(SacEmptyState), findsNothing);
      expect(find.byType(SacErrorState), findsNothing);

      gate.complete(Right(_page([_enr('1')])));
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('shows the error state and retry reloads the queue', (
      tester,
    ) async {
      final repo = _FakeRepo();
      repo.onQueue = (_) async => repo.queueCalls.length == 1
          ? const Left(_boom)
          : Right(_page([_enr('1')]));
      await _pump(tester, repo: repo);

      expect(
          find.text('No se pudieron cargar las inscripciones'), findsOneWidget);
      expect(find.text('Revisa tu conexión e inténtalo de nuevo.'),
          findsOneWidget);
      expect(find.byType(ForbiddenView), findsNothing);

      await tester.tap(_barButton('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls, hasLength(2));
      expect(
          find.text('No se pudieron cargar las inscripciones'), findsNothing);
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = _FakeRepo()
        ..onQueue =
            (_) async => const Left(AuthFailure(message: 'nope', code: 403));
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(
          find.text('No se pudieron cargar las inscripciones'), findsNothing);
      expect(_barButton('Reintentar'), findsNothing);
    });

    group('empty state per filter', () {
      testWidgets('pending, approved and rejected use different texts', (
        tester,
      ) async {
        final repo = _FakeRepo()..onQueue = (_) async => Right(_page(const []));
        await _pump(tester, repo: repo);

        expect(find.text('Nada por validar'), findsOneWidget);
        expect(find.text('No hay inscripciones esperando tu validación.'),
            findsOneWidget);

        await tester.tap(_chip('Aprobadas'));
        await tester.pumpAndSettle();
        expect(find.text('Sin inscripciones aprobadas'), findsOneWidget);
        expect(find.text('Aquí verás las que se resuelvan este año.'),
            findsOneWidget);
        expect(find.text('Nada por validar'), findsNothing);

        await tester.tap(_chip('Rechazadas'));
        await tester.pumpAndSettle();
        expect(find.text('Sin inscripciones rechazadas'), findsOneWidget);
        expect(find.text('Sin inscripciones aprobadas'), findsNothing);

        await tester.tap(_chip('Por validar'));
        await tester.pumpAndSettle();
        expect(find.text('Nada por validar'), findsOneWidget);
      });
    });
  });

  group('pending list', () {
    testWidgets('cards show the club, the "type · field" line and the caption',
        (tester) async {
      final repo = _FakeRepo()
        ..onQueue = (_) async => Right(_page([_enr('1'), _enr('2')]));
      await _pump(tester, repo: repo);

      expect(find.text('Club 1'), findsOneWidget);
      expect(find.text('Club 2'), findsOneWidget);
      expect(find.text('Conquistadores · Asociación Norte'), findsNWidgets(2));
      expect(find.text('Las más antiguas primero'), findsOneWidget);
    });

    testWidgets('the place line skips whatever the server omitted', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onQueue = (_) async => Right(_page([
              _enr('1', localFieldName: ''),
              _enr('2', clubTypeName: '  '),
            ]));
      await _pump(tester, repo: repo);

      expect(find.text('Conquistadores'), findsOneWidget);
      expect(find.text('Asociación Norte'), findsOneWidget);
      expect(find.textContaining('·'), findsNothing);
    });

    testWidgets('chips show the counts of the server', (tester) async {
      await _pump(tester);

      expect(_chipCount(tester, 'Por validar'), 5);
      expect(_chipCount(tester, 'Aprobadas'), 2);
      expect(_chipCount(tester, 'Rechazadas'), 1);
    });

    testWidgets(
        'tapping a chip requests that filter, shows its list and drops the '
        'caption', (tester) async {
      final repo = _FakeRepo()
        ..onQueue = (call) async => Right(
              call.status == _active
                  ? _page([
                      _enr('9',
                          status: _active,
                          reviewedBy: const SupervisionPersonRef(
                            userId: 'r1',
                            name: 'Marta Revisa',
                          )),
                    ])
                  : _page([_enr('1')]),
            );
      await _pump(tester, repo: repo);
      expect(find.text('Club 1'), findsOneWidget);

      await tester.tap(_chip('Aprobadas'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls.last.status, _active);
      expect(repo.queueCalls.last.page, 1);
      expect(find.text('Club 9'), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);
      expect(find.text('Las más antiguas primero'), findsNothing);
      expect(tester.widget<SacFilterChip>(_chip('Aprobadas')).selected, isTrue);
      expect(
          tester.widget<SacFilterChip>(_chip('Por validar')).selected, isFalse);
    });

    testWidgets('tapping the selected chip does not reload', (tester) async {
      final repo = await _pump(tester);

      await tester.tap(_chip('Por validar'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls, hasLength(1));
    });
  });

  group('outcome line of decided cards', () {
    testWidgets('approved by name, approved without reviewer', (tester) async {
      final repo = _FakeRepo()
        ..onQueue = (call) async => Right(
              call.status == _active
                  ? _page([
                      _enr('1',
                          status: _active,
                          reviewedBy: const SupervisionPersonRef(
                            userId: 'r1',
                            name: 'Marta Revisa',
                          )),
                      _enr('2', status: _active),
                    ])
                  : _page(const []),
            );
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Aprobadas'));
      await tester.pumpAndSettle();

      expect(find.text('Aprobada por Marta Revisa'), findsOneWidget);
      expect(find.text('Aprobada'), findsOneWidget);
    });

    testWidgets('rejected shows the reason, else "rejected by", else plain', (
      tester,
    ) async {
      const reviewer = SupervisionPersonRef(userId: 'r1', name: 'Marta Revisa');
      final repo = _FakeRepo()
        ..onQueue = (call) async => Right(
              call.status == _rejected
                  ? _page([
                      _enr('1',
                          status: _rejected,
                          reviewedBy: reviewer,
                          decisionReason: 'Falta la ficha médica'),
                      _enr('2', status: _rejected, reviewedBy: reviewer),
                      _enr('3', status: _rejected),
                    ])
                  : _page(const []),
            );
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Rechazadas'));
      await tester.pumpAndSettle();

      expect(find.text('Falta la ficha médica'), findsOneWidget);
      expect(find.text('Rechazada por Marta Revisa'), findsOneWidget);
      expect(find.text('Rechazada'), findsOneWidget);
    });
  });

  group('load more', () {
    testWidgets('requests the next page as soon as the footer is built', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onQueue = (call) async => Right(
              call.page == 1
                  ? _page([_enr('1'), _enr('2')], total: 3)
                  : _page([_enr('3')], page: 2, total: 3),
            );
      await _pump(tester, repo: repo);

      expect(repo.queueCalls.map((c) => c.page), [1, 2]);
      expect(find.text('Club 3'), findsOneWidget);
      expect(find.text('Club 1'), findsOneWidget);
    });

    testWidgets('shows a progress indicator while the page is in flight', (
      tester,
    ) async {
      final next = Completer<_QueueResult>();
      final repo = _FakeRepo()
        ..onQueue = (call) => call.page == 1
            ? Future.value(Right(_page([_enr('1')], total: 2)))
            : next.future;
      await _pump(tester, repo: repo, settle: false);
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      // One request per page: the footer does not ask again while loading.
      expect(repo.queueCalls.map((c) => c.page), [1, 2]);

      next.complete(Right(_page([_enr('2')], page: 2, total: 2)));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Club 2'), findsOneWidget);
    });

    testWidgets('a failed next page shows its error and retry reloads it', (
      tester,
    ) async {
      var failPage2 = true;
      final repo = _FakeRepo()
        ..onQueue = (call) async {
          if (call.page == 1) return Right(_page([_enr('1')], total: 2));
          return failPage2
              ? const Left(_boom)
              : Right(_page([_enr('2')], page: 2, total: 2));
        };
      await _pump(tester, repo: repo);

      expect(find.text('No se pudieron cargar más inscripciones.'),
          findsOneWidget);
      expect(find.text('Club 1'), findsOneWidget);
      // The failure waits for the button: no automatic retry loop.
      expect(repo.queueCalls.map((c) => c.page), [1, 2]);

      failPage2 = false;
      await tester.tap(_barButton('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.queueCalls.map((c) => c.page), [1, 2, 2]);
      expect(
          find.text('No se pudieron cargar más inscripciones.'), findsNothing);
      expect(find.text('Club 2'), findsOneWidget);
    });
  });

  group('enrollment sheet', () {
    final full = _enr(
      '1',
      board: const SupervisionEnrollmentBoard(
        director: SupervisionPersonRef(userId: 'd', name: 'Ana Directora'),
        deputies: [
          SupervisionPersonRef(userId: 's1', name: 'Beto Sub'),
          SupervisionPersonRef(userId: 's2', name: 'Carla Sub'),
        ],
        treasurer: SupervisionPersonRef(userId: 't', name: 'Dani Tesorero'),
      ),
      meetingDays: 'Sábados 3 pm',
      address: '   ',
      soulsTarget: 12,
      hasFee: true,
      feeAmount: 1500,
      submittedBy: const SupervisionPersonRef(userId: 'e', name: 'Elena Envía'),
      submittedAt: DateTime(2026, 3, 5),
    );

    testWidgets('groups board, operation and request; blank rows are absent', (
      tester,
    ) async {
      final repo = _FakeRepo()..onQueue = (_) async => Right(_page([full]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      expect(find.text('DIRECTIVA'), findsOneWidget);
      expect(find.text('FUNCIONAMIENTO'), findsOneWidget);
      expect(find.text('SOLICITUD'), findsOneWidget);

      expect(_row('Director', 'Ana Directora'), findsOneWidget);
      expect(_rowLabel('Subdirector'), findsNWidgets(2));
      expect(_row('Subdirector', 'Beto Sub'), findsOneWidget);
      expect(_row('Subdirector', 'Carla Sub'), findsOneWidget);
      expect(_row('Tesorero', 'Dani Tesorero'), findsOneWidget);
      expect(_rowLabel('Secretario'), findsNothing);
      expect(_rowLabel('Secretario-tesorero'), findsNothing);

      expect(_row('Reuniones', 'Sábados 3 pm'), findsOneWidget);
      expect(_rowLabel('Dirección'), findsNothing);
      expect(_row('Blanco de almas', '12'), findsOneWidget);

      expect(_row('Enviada por', 'Elena Envía'), findsOneWidget);
      expect(
        _row('Enviada',
            intl.DateFormat.yMMMd('es').format(DateTime(2026, 3, 5))),
        findsOneWidget,
      );
      expect(_rowLabel('Revisó'), findsNothing);
      expect(_rowLabel('Resuelta'), findsNothing);
      expect(_rowLabel('Motivo'), findsNothing);
    });

    testWidgets('the header carries the club and "type · field · year"', (
      tester,
    ) async {
      final repo = _FakeRepo()..onQueue = (_) async => Right(_page([full]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      expect(find.text('Club 1'), findsNWidgets(2));
      expect(find.text('Conquistadores · Asociación Norte · 2026'),
          findsOneWidget);
    });

    testWidgets('fee shows the formatted amount', (tester) async {
      final repo = _FakeRepo()..onQueue = (_) async => Right(_page([full]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      expect(_row('Cuota', r'$1,500.00'), findsOneWidget);
      expect(_rowLabel('Cuota'), findsOneWidget);
    });

    testWidgets('fee reads "Sin cuota" without fee or without an amount', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onQueue = (_) async => Right(_page([
              _enr('1'),
              _enr('2', hasFee: true),
            ]));
      await _pump(tester, repo: repo);

      await _openSheet(tester, 'Club 1');
      expect(_row('Cuota', 'Sin cuota'), findsOneWidget);
      // No board, no request data: only the operation group remains.
      expect(find.text('DIRECTIVA'), findsNothing);
      expect(find.text('SOLICITUD'), findsNothing);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(_sheetOpen, findsNothing);

      await _openSheet(tester, 'Club 2');
      expect(_row('Cuota', 'Sin cuota'), findsOneWidget);
    });

    testWidgets('a decided enrollment shows the review rows', (tester) async {
      final repo = _FakeRepo()
        ..onQueue = (call) async => Right(
              call.status == _rejected
                  ? _page([
                      _enr('7',
                          status: _rejected,
                          reviewedBy: const SupervisionPersonRef(
                              userId: 'r', name: 'Marta Revisa'),
                          reviewedAt: DateTime(2026, 4, 1),
                          decisionReason: 'Falta la ficha médica'),
                    ])
                  : _page(const []),
            );
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Rechazadas'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Club 7');

      expect(_row('Revisó', 'Marta Revisa'), findsOneWidget);
      expect(_row('Motivo', 'Falta la ficha médica'), findsOneWidget);
      expect(
        _row('Resuelta',
            intl.DateFormat.yMMMd('es').format(DateTime(2026, 4, 1))),
        findsOneWidget,
      );
    });
  });

  group('capability gate (S2.5)', () {
    testWidgets('without club_enrollments.validate the sheet has no buttons', (
      tester,
    ) async {
      await _pump(tester, capabilities: const [kSupervisionAppView]);
      await _openSheet(tester, 'Club 1');

      expect(_sheetOpen, findsOneWidget);
      expect(_barButton('Aprobar'), findsNothing);
      expect(_barButton('Rechazar'), findsNothing);
    });

    testWidgets('with the capability a pending enrollment shows both buttons', (
      tester,
    ) async {
      await _pump(tester);
      await _openSheet(tester, 'Club 1');

      expect(_barButton('Aprobar'), findsOneWidget);
      expect(_barButton('Rechazar'), findsOneWidget);
    });

    testWidgets('a decided enrollment has no buttons even for the validator', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onQueue = (call) async => Right(
              call.status == _active
                  ? _page([_enr('4', status: _active)])
                  : _page(const []),
            );
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Aprobadas'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Club 4');

      expect(_sheetOpen, findsOneWidget);
      expect(_barButton('Aprobar'), findsNothing);
      expect(_barButton('Rechazar'), findsNothing);
    });
  });

  group('approve', () {
    testWidgets(
        'confirm dialog, approve with the id, sheet closes, toast and the '
        'item leaves the list', (tester) async {
      final repo = _FakeRepo()
        ..onQueue = (_) async => Right(_page([_enr('1'), _enr('2')]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Aprobar esta inscripción?'), findsOneWidget);
      expect(
          find.text('Club 1 quedará inscrito para este año.'), findsOneWidget);
      expect(repo.approved, isEmpty);

      await tester.tap(_dialogButton('Aprobar'));
      await tester.pumpAndSettle();

      expect(repo.approved, ['1']);
      expect(repo.rejected, isEmpty);
      expect(_sheetOpen, findsNothing);
      expect(find.byType(SacDialog), findsNothing);
      expect(find.text('Inscripción aprobada'), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);
      expect(find.text('Club 2'), findsOneWidget);
      // Local counts follow: one pending less, one approved more.
      expect(_chipCount(tester, 'Por validar'), 4);
      expect(_chipCount(tester, 'Aprobadas'), 3);
    });

    testWidgets('cancel in the dialog calls nothing and keeps the sheet', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.approved, isEmpty);
      expect(find.byType(SacDialog), findsNothing);
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Inscripción aprobada'), findsNothing);
    });

    testWidgets('both buttons are disabled while the request is in flight', (
      tester,
    ) async {
      final gate = Completer<_ItemResult>();
      final repo = _FakeRepo()..onApprove = (_) => gate.future;
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('Aprobar'));
      // The loading button animates forever: advance frames, never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(repo.approved, ['1']);
      expect(
          tester.widget<SacButton>(_barButton('Rechazar')).isEnabled, isFalse);
      expect(tester.widget<SacButton>(_barButton('Aprobar')).isLoading, isTrue);

      gate.complete(Right(_enr('1', status: _active)));
      await tester.pumpAndSettle();
      expect(_sheetOpen, findsNothing);
    });
  });

  group('reject', () {
    testWidgets('a reason shorter than 5 keeps the sheet and calls nothing', (
      tester,
    ) async {
      final repo = await _pump(tester);
      await _openSheet(tester, 'Club 1');

      await _rejectWith(tester, 'abc');

      expect(find.text('Escribe al menos 5 caracteres.'), findsOneWidget);
      expect(find.text('Rechazar inscripción'), findsOneWidget);
      expect(repo.rejected, isEmpty);
      expect(_sheetOpen, findsOneWidget);
    });

    testWidgets('a blank reason asks for the text', (tester) async {
      final repo = await _pump(tester);
      await _openSheet(tester, 'Club 1');

      await _rejectWith(tester, '     ');

      expect(find.text('Escribe el motivo.'), findsOneWidget);
      expect(find.text('Rechazar inscripción'), findsOneWidget);
      expect(repo.rejected, isEmpty);
    });

    testWidgets('exactly 5 characters is accepted', (tester) async {
      final repo = await _pump(tester);
      await _openSheet(tester, 'Club 1');

      await _rejectWith(tester, 'cinco');

      expect(repo.rejected.single.reason, 'cinco');
    });

    testWidgets('the reason is capped at 500 characters', (tester) async {
      final repo = await _pump(tester);
      await _openSheet(tester, 'Club 1');

      await _rejectWith(tester, 'a' * 600);

      expect(repo.rejected.single.reason, hasLength(500));
    });

    testWidgets(
        'a valid reason is trimmed, rejects, closes both sheets and toasts',
        (tester) async {
      final repo = _FakeRepo()
        ..onQueue = (_) async => Right(_page([_enr('1'), _enr('2')]));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _rejectWith(tester, '   Falta la ficha médica  ');

      expect(repo.rejected, hasLength(1));
      expect(repo.rejected.single.id, '1');
      expect(repo.rejected.single.reason, 'Falta la ficha médica');
      expect(_sheetOpen, findsNothing);
      expect(find.text('Rechazar inscripción'), findsNothing);
      expect(find.text('Inscripción rechazada'), findsOneWidget);
      expect(find.text('Club 1'), findsNothing);
      expect(_chipCount(tester, 'Rechazadas'), 2);
    });

    testWidgets('cancel in the decision sheet calls nothing', (tester) async {
      final repo = await _pump(tester);
      await _openSheet(tester, 'Club 1');

      await tester.tap(_barButton('Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(_barButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.rejected, isEmpty);
      expect(find.text('Rechazar inscripción'), findsNothing);
      expect(_sheetOpen, findsOneWidget);
    });
  });

  group('failures', () {
    testWidgets(
        'CE_SELF_REVIEW shows the translated error inline and keeps the '
        'sheet usable', (tester) async {
      final repo = _FakeRepo()
        ..onApprove = (_) async => Left(_coded('CE_SELF_REVIEW'));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approveThroughDialog(tester);

      expect(
        find.text(
            'No puedes validar la inscripción de un club donde tienes un cargo.'),
        findsOneWidget,
      );
      expect(find.text('server says no'), findsNothing);
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Inscripción aprobada'), findsNothing);
      final approve = tester.widget<SacButton>(_barButton('Aprobar'));
      expect(approve.isEnabled, isTrue);
      expect(approve.isLoading, isFalse);
      expect(
          tester.widget<SacButton>(_barButton('Rechazar')).isEnabled, isTrue);

      // Usable again: a second tap reaches the confirmation.
      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.byType(SacDialog), findsOneWidget);
    });

    testWidgets('CE_SELF_REVIEW on reject shows the same inline error', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onReject = (_, __) async => Left(_coded('CE_SELF_REVIEW'));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _rejectWith(tester, 'Motivo válido');

      expect(
        find.text(
            'No puedes validar la inscripción de un club donde tienes un cargo.'),
        findsOneWidget,
      );
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Rechazar inscripción'), findsNothing);
    });

    testWidgets('an unknown code shows the server message inline', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onApprove =
            (_) async => Left(_coded('SOMETHING_ELSE', 'server says no'));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approveThroughDialog(tester);

      expect(find.text('server says no'), findsOneWidget);
      expect(_sheetOpen, findsOneWidget);
      expect(tester.widget<SacButton>(_barButton('Aprobar')).isEnabled, isTrue);
    });

    testWidgets(
        'CE_ENROLLMENT_NOT_PENDING closes the sheet with the "already decided" '
        'toast and refreshes the queue', (tester) async {
      final repo = _FakeRepo();
      repo.onQueue = (_) async => Right(
            repo.queueCalls.length == 1
                ? _page([_enr('1')])
                : _page(const [], counts: const SupervisionEnrollmentCounts()),
          );
      repo.onApprove = (_) async => Left(_coded('CE_ENROLLMENT_NOT_PENDING'));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _approveThroughDialog(tester);

      expect(_sheetOpen, findsNothing);
      expect(find.text('Esta inscripción ya fue resuelta.'), findsOneWidget);
      expect(repo.queueCalls, hasLength(2));
      expect(find.text('Club 1'), findsNothing);
      expect(find.text('Nada por validar'), findsOneWidget);
    });

    testWidgets('CE_ENROLLMENT_NOT_FOUND on reject closes the sheet too', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onReject = (_, __) async => Left(_coded('CE_ENROLLMENT_NOT_FOUND'));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Club 1');

      await _rejectWith(tester, 'Motivo válido');

      expect(_sheetOpen, findsNothing);
      expect(find.text('Esta inscripción ya fue resuelta.'), findsOneWidget);
    });
  });

  group('layout robustness', () {
    const narrow = Size(320, 900);
    const longType = 'Conquistadores de la región metropolitana';
    const longField = 'Asociación del Norte y del Sur Unidas';

    // Long names everywhere, labels short enough for the Ahem font at 1.0.
    // A just-submitted request keeps the trailing relative time short ("Ahora").
    SupervisionEnrollment rich({bool withSecretaryTreasurer = false}) => _enr(
          '1',
          clubTypeName: longType,
          localFieldName: longField,
          board: SupervisionEnrollmentBoard(
            director: const SupervisionPersonRef(
                userId: 'd',
                name: 'Ana María de los Ángeles Directora Sánchez'),
            deputies: const [SupervisionPersonRef(userId: 's', name: 'Beto')],
            secretaryTreasurer: withSecretaryTreasurer
                ? const SupervisionPersonRef(userId: 't', name: 'Dani')
                : null,
          ),
          meetingDays: 'Sábados y domingos por la tarde, después del culto',
          address: 'Avenida Siempre Viva 742, colonia Centro, ciudad grande',
          soulsTarget: 120,
          hasFee: true,
          feeAmount: 1234567.5,
          submittedBy: const SupervisionPersonRef(
              userId: 'e', name: 'Elena de la Cruz Envía Márquez'),
          submittedAt: DateTime.now(),
        );

    // No board and no request data: only the "Cuota" row, whose label is
    // short enough even for the Ahem font at scale 2.0.
    final bare = _enr('1', clubTypeName: longType, localFieldName: longField);

    _FakeRepo repoOf(List<SupervisionEnrollment> items) =>
        _FakeRepo()..onQueue = (_) async => Right(_page([...items, _enr('2')]));

    group('text scale 1.0', () {
      testWidgets('320 wide: list does not overflow', (tester) async {
        await _pump(tester, repo: repoOf([rich()]), size: narrow);

        expectNoLayoutException(tester);
        expect(find.text('Club 1'), findsOneWidget);
      });

      testWidgets('320 wide: sheet does not overflow', (tester) async {
        await _pump(tester, repo: repoOf([rich()]), size: narrow);
        await _openSheet(tester, 'Club 1');

        expectNoLayoutException(tester);
        expect(_sheetOpen, findsOneWidget);
      });

      testWidgets('320 wide: decision sheet does not overflow', (tester) async {
        await _pump(tester, repo: repoOf([rich()]), size: narrow);
        await _openSheet(tester, 'Club 1');
        await tester.tap(_barButton('Rechazar'));
        await tester.pumpAndSettle();

        expectNoLayoutException(tester);
        expect(find.text('Rechazar inscripción'), findsOneWidget);
      });

      testWidgets('320 wide: approve dialog does not overflow', (tester) async {
        await _pump(tester, repo: repoOf([rich()]), size: narrow);
        await _openSheet(tester, 'Club 1');
        await tester.tap(_barButton('Aprobar'));
        await tester.pumpAndSettle();

        expectNoLayoutException(tester);
        expect(find.byType(SacDialog), findsOneWidget);
      });
    });

    group('text scale 2.0', () {
      testWidgets('320 wide: list does not overflow', (tester) async {
        // No dates: the trailing "hace N días" text of a card header is not
        // flexible, and the Ahem font makes it ~2x wider than a real one,
        // which would overflow here for a reason that is not a real bug.
        await _pump(tester, repo: repoOf([bare]), size: narrow, textScale: 2.0);

        expectNoLayoutException(tester);
        expect(find.text('Club 1'), findsOneWidget);
      });

      testWidgets('320 wide: sheet header and buttons do not overflow', (
        tester,
      ) async {
        await _pump(tester, repo: repoOf([bare]), size: narrow, textScale: 2.0);
        await _openSheet(tester, 'Club 1');

        expectNoLayoutException(tester);
        expect(_sheetOpen, findsOneWidget);
        expect(_barButton('Aprobar'), findsOneWidget);
      });

      testWidgets('320 wide: decision sheet does not overflow', (tester) async {
        await _pump(tester, repo: repoOf([bare]), size: narrow, textScale: 2.0);
        await _openSheet(tester, 'Club 1');
        await tester.tap(_barButton('Rechazar'));
        await tester.pumpAndSettle();

        expectNoLayoutException(tester);
        expect(find.text('Rechazar inscripción'), findsOneWidget);
      });

      testWidgets('320 wide: approve dialog does not overflow', (tester) async {
        await _pump(tester, repo: repoOf([bare]), size: narrow, textScale: 2.0);
        await _openSheet(tester, 'Club 1');
        await tester.tap(_barButton('Aprobar'));
        await tester.pumpAndSettle();

        expectNoLayoutException(tester);
        expect(find.byType(SacDialog), findsOneWidget);
      });

      testWidgets(
        '320 wide: sheet rows with long labels do not overflow',
        (tester) async {
          await _pump(
            tester,
            repo: repoOf([rich(withSecretaryTreasurer: true)]),
            size: narrow,
            textScale: 2.0,
          );
          await _openSheet(tester, 'Club 1');

          expectNoLayoutException(tester);
        },
      );
    });

    testWidgets('320 wide, text scale 2.0: error state does not overflow', (
      tester,
    ) async {
      final repo = _FakeRepo()..onQueue = (_) async => const Left(_boom);
      await _pump(tester, repo: repo, size: narrow, textScale: 2.0);

      expectNoLayoutException(tester);
    });
  });

  group('accessibility', () {
    testWidgets('each card is one button labelled with the club name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = _FakeRepo()
        ..onQueue = (_) async => Right(_page([_enr('1'), _enr('2')]));
      await _pump(tester, repo: repo);

      for (final club in ['Club 1', 'Club 2']) {
        final finder = find.bySemanticsLabel(RegExp(club));
        expect(finder, findsOneWidget, reason: club);
        final data = tester.getSemantics(finder);
        expect(data.flagsCollection.isButton, isTrue, reason: club);
        expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: club);
        expect(data.getSemanticsData().label,
            contains('Conquistadores · Asociación Norte'));
      }
      handle.dispose();
    });
  });
}
