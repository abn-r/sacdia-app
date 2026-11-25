/// Widget tests for the territorial transfer / role-assignment requests view
/// and its review flow (decision sheet with an optional comment).
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
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_request.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_requests_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_requests_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/views/supervision_requests_view.dart';

import 'supervision_view_test_harness.dart';

typedef _ListResult = Either<Failure, List<SupervisionRequest>>;
typedef _ItemResult = Either<Failure, SupervisionRequest>;

const _transfer = SupervisionRequestKind.transfer;
const _assignment = SupervisionRequestKind.assignment;
const _pending = SupervisionRequestStatus.pending;
const _approved = SupervisionRequestStatus.approved;
const _rejected = SupervisionRequestStatus.rejected;

const _reviewerCaps = [kSupervisionAppView, kReviewCap];

const _counts = SupervisionPendingCounts(
  territoryLevel: 'union',
  transfers: 3,
  roleAssignments: 2,
);

const _boom = ServerFailure(message: 'boom');

const _shortSurface = Size(800, 800);

ServerFailure _coded(String code, [String message = 'server says no']) =>
    ServerFailure(message: message, errorCode: code);

SupervisionRequest _tr(
  String id, {
  SupervisionRequestStatus status = _pending,
  String? fromClub = 'Club Origen',
  String? fromSection = 'Conquistadores',
  String? toClub = 'Club Destino',
  String? toSection = 'Aventureros',
  String? reason,
  DateTime? createdAt,
  DateTime? reviewedAt,
  String? reviewerName,
  String? reviewComment,
}) =>
    SupervisionRequest(
      kind: _transfer,
      id: id,
      status: status,
      personName: 'Persona $id',
      personId: 'p$id',
      fromClubName: fromClub,
      fromSectionLabel: fromSection,
      toClubName: toClub,
      toSectionLabel: toSection,
      reason: reason,
      createdAt: createdAt,
      reviewedAt: reviewedAt,
      reviewerName: reviewerName,
      reviewComment: reviewComment,
    );

SupervisionRequest _as(
  String id, {
  SupervisionRequestStatus status = _pending,
  String? roleName = 'Consejero',
  String? clubName = 'Club Cargo',
  String? sectionLabel = 'Aventureros',
  String? requestedBy,
  DateTime? createdAt,
  DateTime? reviewedAt,
  String? reviewerName,
  String? reviewComment,
}) =>
    SupervisionRequest(
      kind: _assignment,
      id: id,
      status: status,
      personName: 'Persona $id',
      personId: 'p$id',
      roleName: roleName,
      clubName: clubName,
      sectionLabel: sectionLabel,
      requestedByName: requestedBy,
      createdAt: createdAt,
      reviewedAt: reviewedAt,
      reviewerName: reviewerName,
      reviewComment: reviewComment,
    );

class _Query {
  _Query(this.kind, this.status);
  final SupervisionRequestKind kind;
  final SupervisionRequestStatus status;

  @override
  String toString() => '(${kind.name}, ${status.name})';
}

class _FakeRepo implements SupervisionRequestsRepository {
  final queries = <_Query>[];
  final reviews = <({
    SupervisionRequestKind kind,
    String id,
    bool approve,
    String? comment,
  })>[];

  Future<_ListResult> Function(_Query query) onList =
      (_) async => const Right([]);
  Future<_ItemResult> Function(
      SupervisionRequestKind kind, String id, bool approve)? onReview;

  /// Pending requests keyed by kind; everything else is empty.
  void serve({
    List<SupervisionRequest> transfers = const [],
    List<SupervisionRequest> assignments = const [],
    List<SupervisionRequest> approved = const [],
    List<SupervisionRequest> rejected = const [],
  }) {
    onList = (q) async => Right(switch (q.status) {
          _pending => q.kind == _transfer ? transfers : assignments,
          _approved => approved.where((r) => r.kind == q.kind).toList(),
          _rejected => rejected.where((r) => r.kind == q.kind).toList(),
          _ => const <SupervisionRequest>[],
        });
  }

  @override
  Future<_ListResult> getRequests({
    required SupervisionRequestKind kind,
    required SupervisionRequestStatus status,
    RequestCancelToken? cancelToken,
  }) {
    final query = _Query(kind, status);
    queries.add(query);
    return onList(query);
  }

  @override
  Future<_ItemResult> review({
    required SupervisionRequestKind kind,
    required String requestId,
    required bool approve,
    String? comment,
  }) {
    reviews
        .add((kind: kind, id: requestId, approve: approve, comment: comment));
    final handler = onReview ??
        (k, id, ok) async => Right(
              k == _transfer
                  ? _tr(id, status: ok ? _approved : _rejected)
                  : _as(id, status: ok ? _approved : _rejected),
            );
    return handler(kind, requestId, approve);
  }
}

class _Env {
  _Env(this.repo);
  final _FakeRepo repo;
  int countsCalls = 0;
}

Future<_Env> _pump(
  WidgetTester tester, {
  _FakeRepo? repo,
  FutureOr<SupervisionPendingCounts> Function(int call)? counts,
  List<String> capabilities = _reviewerCaps,
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  final env = _Env(repo ?? _FakeRepo());
  await pumpSupervisionView(
    tester,
    home: const SupervisionRequestsView(),
    user: supervisionUser(capabilities: capabilities),
    size: size,
    textScale: textScale,
    settle: settle,
    overrides: [
      supervisionRequestsRepositoryProvider.overrideWithValue(env.repo),
      supervisionPendingCountsProvider.overrideWith((ref) async {
        env.countsCalls++;
        return (counts ?? (_) => _counts)(env.countsCalls);
      }),
    ],
  );
  return env;
}

Finder _chip(String label) => find.widgetWithText(SacFilterChip, label);

SacFilterChip _chipWidget(WidgetTester tester, String label) =>
    tester.widget<SacFilterChip>(_chip(label));

Future<void> _openSheet(WidgetTester tester, String person) async {
  await tester.tap(find.text(person));
  await tester.pumpAndSettle();
}

Finder _row(String label, String value) => find.byWidgetPredicate(
      (w) => w is SacValueRow && w.label == label && w.value == value,
    );

Finder _rowLabel(String label) =>
    find.byWidgetPredicate((w) => w is SacValueRow && w.label == label);

Finder _barButton(String text) => find.widgetWithText(SacButton, text);

/// The confirm button of the decision sheet: the last button with that text
/// (the action bar of the request sheet sits below it).
Finder _confirm(String text) => _barButton(text).last;

String _date(DateTime when) => intl.DateFormat.yMMMd('es').format(when);

/// Opens the review sheet of [action] ("Aprobar" / "Rechazar"), writes
/// [comment] (when given) and confirms.
Future<void> _review(
  WidgetTester tester,
  String action, {
  String? comment,
}) async {
  await tester.tap(_barButton(action));
  await tester.pumpAndSettle();
  if (comment != null) {
    await tester.enterText(find.byType(TextFormField), comment);
    await tester.pump();
  }
  await tester.tap(_confirm(action));
  await tester.pumpAndSettle();
}

/// Marker of the request sheet.
final _sheetOpen = find.text('SOLICITUD');

/// Flings the list down from [onItem] past the trigger distance of the
/// RefreshIndicator and lets the refresh finish.
Future<void> _pullToRefresh(WidgetTester tester, Finder onItem) async {
  await tester.fling(onItem, const Offset(0, 400), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

/// The chip row is a horizontal list: at large text scales it scrolls.
Future<void> _tapChip(WidgetTester tester, String label) async {
  await tester.ensureVisible(_chip(label));
  await tester.pumpAndSettle();
  await tester.tap(_chip(label));
  await tester.pumpAndSettle();
}

double _top(WidgetTester tester, String text) =>
    tester.getTopLeft(find.text(text)).dy;

void main() {
  setUpAll(initSupervisionViewTests);

  group('default query and filters', () {
    testWidgets('opens on pending transfers', (tester) async {
      final env = await _pump(tester);

      expect(env.repo.queries.map((q) => '$q'), ['(transfer, pending)']);
      expect(_chipWidget(tester, 'Traslados').selected, isTrue);
      expect(_chipWidget(tester, 'Asignaciones').selected, isFalse);
      expect(_chipWidget(tester, 'Resueltas').selected, isFalse);
    });

    testWidgets('kind chips carry the pending counts', (tester) async {
      await _pump(tester);

      expect(_chipWidget(tester, 'Traslados').count, 3);
      expect(_chipWidget(tester, 'Asignaciones').count, 2);
      expect(_chipWidget(tester, 'Resueltas').count, isNull);
    });

    testWidgets('kind chips carry no count while the counts load', (
      tester,
    ) async {
      final gate = Completer<SupervisionPendingCounts>();
      await _pump(tester, counts: (_) => gate.future, settle: false);

      expect(_chipWidget(tester, 'Traslados').count, isNull);
      expect(_chipWidget(tester, 'Asignaciones').count, isNull);

      gate.complete(_counts);
      await tester.pumpAndSettle();
      expect(_chipWidget(tester, 'Traslados').count, 3);
    });

    testWidgets('kind chips carry no count when the counts fail', (
      tester,
    ) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(
        tester,
        repo: repo,
        counts: (_) => throw const SupervisionLoadException('boom'),
      );

      expect(_chipWidget(tester, 'Traslados').count, isNull);
      expect(_chipWidget(tester, 'Asignaciones').count, isNull);
      // The list is not affected by the failed counts.
      expect(find.text('Persona t1'), findsOneWidget);
    });

    testWidgets('switching the kind queries the assignments', (tester) async {
      final repo = _FakeRepo()
        ..serve(transfers: [_tr('t1')], assignments: [_as('a1')]);
      await _pump(tester, repo: repo);
      expect(find.text('Persona t1'), findsOneWidget);

      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();

      expect(repo.queries.last.kind, _assignment);
      expect(repo.queries.last.status, _pending);
      expect(find.text('Persona a1'), findsOneWidget);
      expect(find.text('Persona t1'), findsNothing);
      expect(_chipWidget(tester, 'Asignaciones').selected, isTrue);
      expect(_chipWidget(tester, 'Traslados').selected, isFalse);
    });

    testWidgets(
        '"Resueltas" merges approved and rejected, newest decision first, '
        'and toggles back', (tester) async {
      final repo = _FakeRepo()
        ..serve(
          transfers: [_tr('p1')],
          approved: [
            _tr('old', status: _approved, reviewedAt: DateTime(2026, 3, 1)),
            _tr('new', status: _approved, reviewedAt: DateTime(2026, 5, 1)),
          ],
          rejected: [
            _tr('mid', status: _rejected, reviewedAt: DateTime(2026, 4, 1)),
          ],
        );
      await _pump(tester, repo: repo);
      expect(find.text('Persona p1'), findsOneWidget);

      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();

      final decided = repo.queries.map((q) => '$q').toList();
      expect(decided,
          containsAll(['(transfer, approved)', '(transfer, rejected)']));
      expect(find.text('Persona p1'), findsNothing);
      expect(_chipWidget(tester, 'Resueltas').selected, isTrue);
      final order = [
        _top(tester, 'Persona new'),
        _top(tester, 'Persona mid'),
        _top(tester, 'Persona old'),
      ];
      expect(order[0], lessThan(order[1]));
      expect(order[1], lessThan(order[2]));

      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();
      expect(find.text('Persona p1'), findsOneWidget);
      expect(find.text('Persona new'), findsNothing);
      expect(_chipWidget(tester, 'Resueltas').selected, isFalse);
    });

    testWidgets('"Resueltas" keeps the selected kind', (tester) async {
      final repo = _FakeRepo()..serve(approved: [_as('a1', status: _approved)]);
      await _pump(tester, repo: repo);

      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();

      expect(
        repo.queries.map((q) => '$q'),
        containsAll(['(assignment, approved)', '(assignment, rejected)']),
      );
      expect(find.text('Persona a1'), findsOneWidget);
    });
  });

  group('cards', () {
    testWidgets('a transfer reads "De A a B" with club and section', (
      tester,
    ) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);

      expect(
          find.text(
              'De Club Origen (Conquistadores) a Club Destino (Aventureros)'),
          findsOneWidget);
    });

    testWidgets('a transfer summary keeps what the server sent', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..serve(transfers: [
          _tr('t1', fromSection: null, toSection: ''),
          _tr('t2', fromClub: null, fromSection: 'Guías Mayores'),
        ]);
      await _pump(tester, repo: repo);

      expect(find.text('De Club Origen a Club Destino'), findsOneWidget);
      expect(find.text('De Guías Mayores a Club Destino (Aventureros)'),
          findsOneWidget);
    });

    testWidgets('a transfer with a missing club falls back to a placeholder', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..serve(transfers: [
          _tr('t1',
              fromClub: null, fromSection: null, toClub: '  ', toSection: null),
        ]);
      await _pump(tester, repo: repo);

      expect(find.text('De club sin nombre a club sin nombre'), findsOneWidget);
    });

    testWidgets('an assignment reads "Role en Club (Section)"', (tester) async {
      final repo = _FakeRepo()..serve(assignments: [_as('a1')]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();

      expect(
          find.text('Consejero en Club Cargo (Aventureros)'), findsOneWidget);
    });

    testWidgets('an assignment with a missing role or club falls back', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..serve(assignments: [
          _as('a1', roleName: null, clubName: null, sectionLabel: null),
          _as('a2', sectionLabel: null),
        ]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();

      expect(find.text('Cargo en club sin nombre'), findsOneWidget);
      expect(find.text('Consejero en Club Cargo'), findsOneWidget);
    });

    testWidgets('decided cards show who approved and why it was rejected', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..serve(
          approved: [
            _tr('a1', status: _approved, reviewerName: 'Marta Revisa'),
            _tr('a2', status: _approved),
          ],
          rejected: [
            _tr('r1',
                status: _rejected,
                reviewerName: 'Marta Revisa',
                reviewComment: 'Falta el aval del director'),
            _tr('r2', status: _rejected, reviewerName: 'Marta Revisa'),
            _tr('r3', status: _rejected, reviewComment: '   '),
          ],
        );
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();

      expect(find.text('Aprobada por Marta Revisa'), findsOneWidget);
      expect(find.text('Aprobada'), findsOneWidget);
      expect(find.text('Falta el aval del director'), findsOneWidget);
      expect(find.text('Rechazada por Marta Revisa'), findsOneWidget);
      expect(find.text('Rechazada'), findsOneWidget);
    });

    testWidgets('a pending card has no outcome line', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);

      expect(find.textContaining('Aprobada'), findsNothing);
      expect(find.textContaining('Rechazada'), findsNothing);
    });
  });

  group('load states', () {
    testWidgets('shows the skeleton while loading', (tester) async {
      final gate = Completer<_ListResult>();
      final repo = _FakeRepo()..onList = (_) => gate.future;
      await _pump(tester, repo: repo, settle: false);

      expect(find.byType(SacSkeletonList), findsOneWidget);

      gate.complete(Right([_tr('t1')]));
      await tester.pumpAndSettle();
      expect(find.byType(SacSkeletonList), findsNothing);
      expect(find.text('Persona t1'), findsOneWidget);
    });

    testWidgets('shows the error state and retry reloads the list', (
      tester,
    ) async {
      final repo = _FakeRepo();
      repo.onList = (_) async =>
          repo.queries.length == 1 ? const Left(_boom) : Right([_tr('t1')]);
      await _pump(tester, repo: repo);

      expect(
          find.text('No se pudieron cargar las solicitudes'), findsOneWidget);
      expect(find.text('Revisa tu conexión e inténtalo de nuevo.'),
          findsOneWidget);

      await tester.tap(_barButton('Reintentar'));
      await tester.pumpAndSettle();

      expect(repo.queries, hasLength(2));
      expect(find.text('No se pudieron cargar las solicitudes'), findsNothing);
      expect(find.text('Persona t1'), findsOneWidget);
    });

    testWidgets('retry also refetches the pending counts', (tester) async {
      final repo = _FakeRepo();
      repo.onList = (_) async =>
          repo.queries.length == 1 ? const Left(_boom) : const Right([]);
      final env = await _pump(tester, repo: repo);
      expect(env.countsCalls, 1);

      await tester.tap(_barButton('Reintentar'));
      await tester.pumpAndSettle();

      expect(env.countsCalls, 2);
    });

    testWidgets('one failing half of "Resueltas" shows the error state', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..onList = (q) async => q.status == _rejected
            ? const Left(_boom)
            : Right([_tr('a1', status: _approved)]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();

      expect(
          find.text('No se pudieron cargar las solicitudes'), findsOneWidget);
      expect(find.text('Persona a1'), findsNothing);
    });

    testWidgets('a 403 renders the ForbiddenView and no retry', (tester) async {
      final repo = _FakeRepo()
        ..onList =
            (_) async => const Left(AuthFailure(message: 'nope', code: 403));
      await _pump(tester, repo: repo);

      expect(find.byType(ForbiddenView), findsOneWidget);
      expect(find.text('No se pudieron cargar las solicitudes'), findsNothing);
      expect(_barButton('Reintentar'), findsNothing);
    });

    testWidgets('empty states have four different titles', (tester) async {
      await _pump(tester);

      expect(find.text('Sin traslados por revisar'), findsOneWidget);
      expect(find.text('Cuando un club lo solicite, aparecerá aquí.'),
          findsOneWidget);

      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      expect(find.text('Sin asignaciones por revisar'), findsOneWidget);
      expect(find.text('Sin traslados por revisar'), findsNothing);

      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();
      expect(find.text('Sin asignaciones resueltas'), findsOneWidget);
      expect(find.text('Aquí verás las solicitudes aprobadas y rechazadas.'),
          findsOneWidget);

      await tester.tap(_chip('Traslados'));
      await tester.pumpAndSettle();
      expect(find.text('Sin traslados resueltos'), findsOneWidget);
      expect(find.text('Sin asignaciones resueltas'), findsNothing);
    });
  });

  group('request sheet facts', () {
    testWidgets('a pending transfer shows origin, destination, reason, date', (
      tester,
    ) async {
      final created = DateTime(2026, 3, 5);
      final repo = _FakeRepo()
        ..serve(transfers: [
          _tr('t1', reason: 'Se muda de ciudad', createdAt: created),
        ]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      expect(find.text('Solicitud de traslado'), findsOneWidget);
      expect(_row('Origen', 'Club Origen (Conquistadores)'), findsOneWidget);
      expect(_row('Destino', 'Club Destino (Aventureros)'), findsOneWidget);
      expect(_row('Motivo', 'Se muda de ciudad'), findsOneWidget);
      expect(_row('Fecha', _date(created)), findsOneWidget);
      // Only decided requests carry a review group.
      expect(find.text('REVISIÓN'), findsNothing);
      expect(_rowLabel('Revisó'), findsNothing);
      expect(_rowLabel('Cargo'), findsNothing);
    });

    testWidgets('blank optional rows are absent', (tester) async {
      final repo = _FakeRepo()
        ..serve(transfers: [
          _tr('t1', reason: '  ', fromClub: null, fromSection: null),
        ]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      expect(_rowLabel('Motivo'), findsNothing);
      expect(_rowLabel('Origen'), findsNothing);
      expect(_rowLabel('Destino'), findsOneWidget);
      expect(_rowLabel('Fecha'), findsNothing);
    });

    testWidgets('a pending assignment shows role, club, requester, date', (
      tester,
    ) async {
      final created = DateTime(2026, 2, 10);
      final repo = _FakeRepo()
        ..serve(assignments: [
          _as('a1', requestedBy: 'Luis Director', createdAt: created),
        ]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      expect(find.text('Solicitud de cargo'), findsOneWidget);
      expect(_row('Cargo', 'Consejero'), findsOneWidget);
      expect(_row('Club', 'Club Cargo (Aventureros)'), findsOneWidget);
      expect(_row('Solicitó', 'Luis Director'), findsOneWidget);
      expect(_row('Fecha', _date(created)), findsOneWidget);
      expect(_rowLabel('Origen'), findsNothing);
      expect(_rowLabel('Destino'), findsNothing);
      expect(find.text('REVISIÓN'), findsNothing);
    });

    testWidgets('a decided request adds the review group', (tester) async {
      final reviewed = DateTime(2026, 4, 1);
      final repo = _FakeRepo()
        ..serve(rejected: [
          _tr('r1',
              status: _rejected,
              reviewerName: 'Marta Revisa',
              reviewedAt: reviewed,
              reviewComment: 'Falta el aval'),
        ]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona r1');

      expect(find.text('REVISIÓN'), findsOneWidget);
      expect(_row('Revisó', 'Marta Revisa'), findsOneWidget);
      expect(_row('Resuelta', _date(reviewed)), findsOneWidget);
      expect(_row('Comentario', 'Falta el aval'), findsOneWidget);
    });

    testWidgets('a decided request without review data has no review group', (
      tester,
    ) async {
      final repo = _FakeRepo()..serve(approved: [_tr('a1', status: _approved)]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      expect(_sheetOpen, findsOneWidget);
      expect(find.text('REVISIÓN'), findsNothing);
    });
  });

  group('capability gate (S5.5)', () {
    testWidgets('without requests.review_territory the sheet has no buttons', (
      tester,
    ) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(
        tester,
        repo: repo,
        capabilities: const [kSupervisionAppView],
      );
      await _openSheet(tester, 'Persona t1');

      expect(_sheetOpen, findsOneWidget);
      expect(_barButton('Aprobar'), findsNothing);
      expect(_barButton('Rechazar'), findsNothing);
    });

    testWidgets('with the capability a pending request shows both buttons', (
      tester,
    ) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      expect(_barButton('Aprobar'), findsOneWidget);
      expect(_barButton('Rechazar'), findsOneWidget);
    });

    testWidgets('a decided request has no buttons even for the reviewer', (
      tester,
    ) async {
      final repo = _FakeRepo()..serve(approved: [_tr('a1', status: _approved)]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      expect(_sheetOpen, findsOneWidget);
      expect(_barButton('Aprobar'), findsNothing);
      expect(_barButton('Rechazar'), findsNothing);
    });
  });

  group('approve', () {
    testWidgets(
        'an empty comment approves with no comment, closes the sheet and '
        'toasts', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      final env = await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Aprobar traslado'), findsOneWidget);
      expect(find.text('Comentario (opcional)'), findsOneWidget);
      // The decision sheet repeats what is being approved.
      expect(
        find.text(
            'De Club Origen (Conquistadores) a Club Destino (Aventureros)'),
        findsNWidgets(2),
      );
      await tester.tap(_confirm('Aprobar'));
      await tester.pumpAndSettle();

      expect(repo.reviews, hasLength(1));
      expect(repo.reviews.single.kind, _transfer);
      expect(repo.reviews.single.id, 't1');
      expect(repo.reviews.single.approve, isTrue);
      expect(repo.reviews.single.comment, isNull);
      expect(_sheetOpen, findsNothing);
      expect(find.text('Solicitud aprobada'), findsOneWidget);
      // The list and the pending counts were invalidated and refetched.
      expect(env.countsCalls, 2);
    });

    testWidgets('a comment is trimmed and sent', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Aprobar', comment: '   Todo en orden  ');

      expect(repo.reviews.single.approve, isTrue);
      expect(repo.reviews.single.comment, 'Todo en orden');
    });

    testWidgets('an assignment uses its own title and kind', (tester) async {
      final repo = _FakeRepo()..serve(assignments: [_as('a1')]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Aprobar asignación'), findsOneWidget);
      expect(
          find.text('Consejero en Club Cargo (Aventureros)'), findsNWidgets(2));
      await tester.tap(_confirm('Aprobar'));
      await tester.pumpAndSettle();

      expect(repo.reviews.single.kind, _assignment);
      expect(repo.reviews.single.id, 'a1');
    });

    testWidgets('the approved request leaves the pending list', (tester) async {
      final repo = _FakeRepo();
      var approvedT1 = false;
      repo.onList = (q) async => Right(
            q.status == _pending
                ? [if (!approvedT1) _tr('t1'), _tr('t2')]
                : const [],
          );
      repo.onReview = (k, id, ok) async {
        approvedT1 = true;
        return Right(_tr(id, status: _approved));
      };
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Aprobar');

      expect(find.text('Persona t1'), findsNothing);
      expect(find.text('Persona t2'), findsOneWidget);
    });

    testWidgets('cancel in the decision sheet calls nothing', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      await tester.tap(_barButton('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.reviews, isEmpty);
      expect(find.text('Aprobar traslado'), findsNothing);
      expect(_sheetOpen, findsOneWidget);
    });

    testWidgets('both buttons are disabled while the review is in flight', (
      tester,
    ) async {
      final gate = Completer<_ItemResult>();
      final repo = _FakeRepo()
        ..serve(transfers: [_tr('t1')])
        ..onReview = (_, __, ___) => gate.future;
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      await tester.tap(_confirm('Aprobar'));
      // The loading button animates forever: advance frames, never settle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.reviews, hasLength(1));
      expect(
          tester.widget<SacButton>(_barButton('Rechazar')).isEnabled, isFalse);
      expect(tester.widget<SacButton>(_barButton('Aprobar')).isLoading, isTrue);

      gate.complete(Right(_tr('t1', status: _approved)));
      await tester.pumpAndSettle();
      expect(_sheetOpen, findsNothing);
    });
  });

  group('reject', () {
    testWidgets('a comment is trimmed, rejects, closes and toasts', (
      tester,
    ) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await tester.tap(_barButton('Rechazar'));
      await tester.pumpAndSettle();
      expect(find.text('Rechazar traslado'), findsOneWidget);
      expect(
          find.text('Explica el motivo a quien lo solicitó'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '  Falta el aval  ');
      await tester.pump();
      await tester.tap(_confirm('Rechazar'));
      await tester.pumpAndSettle();

      expect(repo.reviews.single.approve, isFalse);
      expect(repo.reviews.single.comment, 'Falta el aval');
      expect(_sheetOpen, findsNothing);
      expect(find.text('Solicitud rechazada'), findsOneWidget);
    });

    testWidgets('the comment is optional also for a rejection', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Rechazar');

      expect(repo.reviews.single.approve, isFalse);
      expect(repo.reviews.single.comment, isNull);
    });

    testWidgets('the comment is capped at 500 characters', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Rechazar', comment: 'a' * 600);

      expect(repo.reviews.single.comment, hasLength(500));
    });

    testWidgets('an assignment rejection uses its own title', (tester) async {
      final repo = _FakeRepo()..serve(assignments: [_as('a1')]);
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      await tester.tap(_barButton('Rechazar'));
      await tester.pumpAndSettle();

      expect(find.text('Rechazar asignación'), findsOneWidget);
    });
  });

  group('failures', () {
    testWidgets(
        'REQUEST_TRANSFER_ALREADY_REVIEWED closes the sheet with the '
        '"already resolved" toast and refreshes the list', (tester) async {
      final repo = _FakeRepo();
      repo.onList =
          (_) async => Right(repo.queries.length == 1 ? [_tr('t1')] : const []);
      repo.onReview = (_, __, ___) async =>
          Left(_coded('REQUEST_TRANSFER_ALREADY_REVIEWED'));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Aprobar');

      expect(_sheetOpen, findsNothing);
      expect(find.text('Esta solicitud ya fue resuelta.'), findsOneWidget);
      expect(find.text('Persona t1'), findsNothing);
      expect(find.text('Sin traslados por revisar'), findsOneWidget);
    });

    testWidgets('REQUEST_ASSIGNMENT_NOT_FOUND closes the sheet too', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..serve(assignments: [_as('a1')])
        ..onReview =
            (_, __, ___) async => Left(_coded('REQUEST_ASSIGNMENT_NOT_FOUND'));
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      await _review(tester, 'Rechazar');

      expect(_sheetOpen, findsNothing);
      expect(find.text('Esta solicitud ya fue resuelta.'), findsOneWidget);
    });

    testWidgets(
        'REQUEST_ROLE_SLOT_LIMIT_REACHED shows the translated error inline '
        'and keeps the sheet usable', (tester) async {
      final repo = _FakeRepo()
        ..serve(assignments: [_as('a1')])
        ..onReview = (_, __, ___) async =>
            Left(_coded('REQUEST_ROLE_SLOT_LIMIT_REACHED'));
      await _pump(tester, repo: repo);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      await _review(tester, 'Aprobar');

      expect(
        find.text('El club ya tiene ocupados todos los puestos de ese cargo.'),
        findsOneWidget,
      );
      expect(find.text('server says no'), findsNothing);
      expect(_sheetOpen, findsOneWidget);
      expect(find.text('Solicitud aprobada'), findsNothing);
      final approve = tester.widget<SacButton>(_barButton('Aprobar'));
      expect(approve.isEnabled, isTrue);
      expect(approve.isLoading, isFalse);
      expect(
          tester.widget<SacButton>(_barButton('Rechazar')).isEnabled, isTrue);

      // Usable again: a second tap reaches the decision sheet.
      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();
      expect(find.text('Aprobar asignación'), findsOneWidget);
    });

    testWidgets('an unknown code shows the server message inline', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..serve(transfers: [_tr('t1')])
        ..onReview = (_, __, ___) async => Left(_coded('SOMETHING_ELSE'));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Aprobar');

      expect(find.text('server says no'), findsOneWidget);
      expect(_sheetOpen, findsOneWidget);
      expect(tester.widget<SacButton>(_barButton('Aprobar')).isEnabled, isTrue);
    });

    testWidgets('a failure without a code shows the server message inline', (
      tester,
    ) async {
      final repo = _FakeRepo()
        ..serve(transfers: [_tr('t1')])
        ..onReview = (_, __, ___) async => const Left(_boom);
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Rechazar');

      expect(find.text('boom'), findsOneWidget);
      expect(_sheetOpen, findsOneWidget);
    });

    testWidgets('the inline error clears on the next attempt', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      var fail = true;
      repo.onReview = (_, id, __) async => fail
          ? Left(_coded('SOMETHING_ELSE'))
          : Right(_tr(id, status: _approved));
      await _pump(tester, repo: repo);
      await _openSheet(tester, 'Persona t1');

      await _review(tester, 'Aprobar');
      expect(find.text('server says no'), findsOneWidget);

      fail = false;
      await _review(tester, 'Aprobar');
      expect(_sheetOpen, findsNothing);
      expect(find.text('server says no'), findsNothing);
      expect(find.text('Solicitud aprobada'), findsOneWidget);
    });
  });

  group('pull to refresh', () {
    testWidgets('refetches the list and the pending counts', (tester) async {
      final repo = _FakeRepo()..serve(transfers: [_tr('t1')]);
      // A short surface: the trigger distance is 25% of the viewport height.
      final env = await _pump(tester, repo: repo, size: _shortSurface);
      expect(repo.queries, hasLength(1));
      expect(env.countsCalls, 1);

      await _pullToRefresh(tester, find.text('Persona t1'));

      expect(repo.queries, hasLength(2));
      expect(env.countsCalls, 2);
      expect(find.text('Persona t1'), findsOneWidget);
    });

    testWidgets('on "Resueltas" refetches both halves', (tester) async {
      final repo = _FakeRepo()..serve(approved: [_tr('a1', status: _approved)]);
      await _pump(tester, repo: repo, size: _shortSurface);
      await tester.tap(_chip('Resueltas'));
      await tester.pumpAndSettle();
      final before = repo.queries.length;

      await _pullToRefresh(tester, find.text('Persona a1'));

      final refetched = repo.queries.skip(before).map((q) => '$q');
      expect(refetched,
          containsAll(['(transfer, approved)', '(transfer, rejected)']));
    });
  });

  group('layout robustness', () {
    const narrow = Size(320, 900);

    // Long names; no dates so the trailing relative time of a card header
    // (not flexible, and ~2x wider under the Ahem font) cannot overflow for
    // a reason that is not a real bug.
    final longTransfer = _tr(
      't1',
      fromClub: 'Club Conquistadores de la Región Metropolitana Norte',
      fromSection: 'Conquistadores',
      toClub: 'Club Aventureros del Valle Central y Alrededores',
      toSection: 'Aventureros',
      reason: 'Se muda de ciudad por motivos de trabajo de sus padres',
    );
    final longAssignment = _as(
      'a1',
      roleName: 'Subdirector de la sección de Guías Mayores',
      clubName: 'Club Conquistadores de la Región Metropolitana Norte',
      requestedBy: 'Elena de la Cruz Envía Márquez',
    );

    _FakeRepo repo() => _FakeRepo()
      ..serve(
        transfers: [longTransfer],
        assignments: [longAssignment],
      );

    for (final scale in [1.0, 2.0]) {
      group('text scale $scale', () {
        testWidgets('320 wide: transfer list does not overflow', (
          tester,
        ) async {
          await _pump(tester, repo: repo(), size: narrow, textScale: scale);

          expectNoLayoutException(tester);
          expect(find.text('Persona t1'), findsOneWidget);
        });

        testWidgets('320 wide: assignment list does not overflow', (
          tester,
        ) async {
          await _pump(tester, repo: repo(), size: narrow, textScale: scale);
          await _tapChip(tester, 'Asignaciones');

          expectNoLayoutException(tester);
          expect(find.text('Persona a1'), findsOneWidget);
        });

        testWidgets('320 wide: decision sheet does not overflow', (
          tester,
        ) async {
          await _pump(tester, repo: repo(), size: narrow, textScale: scale);
          await _openSheet(tester, 'Persona t1');
          await tester.tap(_barButton('Rechazar'));
          await tester.pumpAndSettle();

          expectNoLayoutException(tester);
          expect(find.text('Rechazar traslado'), findsOneWidget);
        });

        testWidgets('320 wide: error state does not overflow', (tester) async {
          final failing = _FakeRepo()..onList = (_) async => const Left(_boom);
          await _pump(tester, repo: failing, size: narrow, textScale: scale);

          expectNoLayoutException(tester);
        });
      });
    }

    testWidgets('320 wide, text scale 1.0: transfer sheet does not overflow', (
      tester,
    ) async {
      await _pump(tester, repo: repo(), size: narrow);
      await _openSheet(tester, 'Persona t1');

      expectNoLayoutException(tester);
      expect(_sheetOpen, findsOneWidget);
    });

    testWidgets('320 wide, text scale 1.0: assignment sheet does not overflow',
        (tester) async {
      await _pump(tester, repo: repo(), size: narrow);
      await tester.tap(_chip('Asignaciones'));
      await tester.pumpAndSettle();
      await _openSheet(tester, 'Persona a1');

      expectNoLayoutException(tester);
      expect(_sheetOpen, findsOneWidget);
    });

    testWidgets(
        '320 wide, text scale 2.0: sheet header and buttons do not overflow', (
      tester,
    ) async {
      // One short-label row only: the Ahem font makes any label wider than
      // ~6 characters overflow at this scale, which a real font does not.
      final single = _FakeRepo()
        ..serve(transfers: [
          _tr('t1', toClub: null, toSection: null, fromClub: 'Club Origen'),
        ]);
      await _pump(tester, repo: single, size: narrow, textScale: 2.0);
      await _openSheet(tester, 'Persona t1');

      expectNoLayoutException(tester);
      expect(_sheetOpen, findsOneWidget);
      expect(_barButton('Aprobar'), findsOneWidget);
    });

    testWidgets(
        '320 wide, text scale 2.0: approve decision sheet does not '
        'overflow', (tester) async {
      final single = _FakeRepo()..serve(transfers: [_tr('t1')]);
      await _pump(tester, repo: single, size: narrow, textScale: 2.0);
      await _openSheet(tester, 'Persona t1');
      await tester.tap(_barButton('Aprobar'));
      await tester.pumpAndSettle();

      expectNoLayoutException(tester);
      expect(find.text('Aprobar traslado'), findsOneWidget);
    });
  });

  group('accessibility', () {
    testWidgets('each card is one button labelled with the person name', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final repo = _FakeRepo()..serve(transfers: [_tr('t1'), _tr('t2')]);
      await _pump(tester, repo: repo);

      for (final person in ['Persona t1', 'Persona t2']) {
        final finder = find.bySemanticsLabel(RegExp(person));
        expect(finder, findsOneWidget, reason: person);
        final data = tester.getSemantics(finder);
        expect(data.flagsCollection.isButton, isTrue, reason: person);
        expect(data.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: person);
        expect(data.getSemanticsData().label, contains('De Club Origen'));
      }
      handle.dispose();
    });
  });
}
