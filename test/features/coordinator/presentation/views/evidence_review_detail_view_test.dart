/// Tests for the redesigned EvidenceReviewDetailView ("Revisar evidencia").
library;

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_club.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/coordinator_scope.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/sla_dashboard.dart';
import 'package:sacdia_app/features/coordinator/domain/repositories/coordinator_repository.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/views/evidence_review_detail_view.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/approval_action_buttons.dart';

import '../../coordinator_test_harness.dart';

const _sla = SlaDashboard(
  investiture: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  evidence: SlaStat(pending: 1, avgDays: 1, overdue: 0),
  camporee: SlaStat(pending: 0, avgDays: 0, overdue: 0),
  throughput: [],
  pipeline: [],
);

class _FakeRepository implements CoordinatorRepository {
  _FakeRepository({required this.detail});

  EvidenceReviewItem detail;
  Failure? actionFailure;

  int detailCalls = 0;
  int pendingCalls = 0;
  int slaCalls = 0;
  final approvals = <String?>[];
  final rejections = <String>[];

  @override
  Future<Either<Failure, EvidenceReviewItem>> getEvidenceDetail({
    required EvidenceReviewType type,
    required String id,
    RequestCancelToken? cancelToken,
  }) async {
    detailCalls++;
    return Right(detail);
  }

  @override
  Future<Either<Failure, EvidenceReviewPage>> getPendingEvidence({
    int page = 1,
    int limit = kPendingEvidencePageSize,
    EvidenceReviewType? type,
    RequestCancelToken? cancelToken,
  }) async {
    pendingCalls++;
    return Right(
      EvidenceReviewPage(items: const [], total: 0, page: page, limit: limit),
    );
  }

  @override
  Future<Either<Failure, SlaDashboard>> getSlaDashboard({
    RequestCancelToken? cancelToken,
  }) async {
    slaCalls++;
    return const Right(_sla);
  }

  @override
  Future<Either<Failure, void>> approveEvidence({
    required EvidenceReviewType type,
    required String id,
    String? comment,
  }) async {
    if (actionFailure != null) return Left(actionFailure!);
    approvals.add(comment);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> rejectEvidence({
    required EvidenceReviewType type,
    required String id,
    required String rejectionReason,
  }) async {
    if (actionFailure != null) return Left(actionFailure!);
    rejections.add(rejectionReason);
    return const Right(null);
  }

  @override
  Future<Either<Failure, CoordinatorScope>> getMyScope({
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<CoordinatorClub>>> listClubs({
    int? localFieldId,
    RequestCancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> bulkApproveEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
  }) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> bulkRejectEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
    required String rejectionReason,
  }) =>
      throw UnimplementedError();
}

EvidenceReviewItem _evidence({
  EvidenceReviewStatus status = EvidenceReviewStatus.pending,
  List<EvidenceFile>? files,
  List<EvidenceHistoryEntry>? history,
}) =>
    EvidenceReviewItem(
      id: '5',
      type: EvidenceReviewType.classType,
      status: status,
      memberName: 'Ana Pérez',
      context: 'Amigo · Requisito 1',
      clubSectionLabel: 'Club Orión · Conquistadores',
      submittedAt: DateTime(2026, 10, 1),
      fileCount: 2,
      files: files ??
          const [
            EvidenceFile(
              id: 'f1',
              url: 'https://files.test/foto.jpg',
              name: 'foto.jpg',
              mimeType: 'image/jpeg',
            ),
            EvidenceFile(
              id: 'f2',
              url: 'https://files.test/informe.pdf',
              name: 'informe.pdf',
              mimeType: 'application/pdf',
            ),
          ],
      history: history ??
          [
            EvidenceHistoryEntry(
              id: 'h1',
              action: 'SUBMITTED',
              actorName: 'Ana Pérez',
              createdAt: DateTime(2026, 10, 1, 9, 30),
            ),
            EvidenceHistoryEntry(
              id: 'h2',
              action: 'REJECTED',
              actorName: 'Carlos Coordinador',
              comment: 'Falta una foto',
              createdAt: DateTime(2026, 10, 2, 18, 5),
            ),
          ],
    );

late ProviderContainer _container;

Future<void> _pumpDetail(
  WidgetTester tester,
  _FakeRepository repo, {
  bool openFromHome = true,
}) async {
  useTallSurface(tester);

  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, __) => Scaffold(
          body: Center(
            child: Column(
              children: [
                const Text('page:home'),
                TextButton(
                  onPressed: () => context.push('/detail'),
                  child: const Text('open'),
                ),
              ],
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/detail',
        builder: (_, __) => const EvidenceReviewDetailView(
          type: EvidenceReviewType.classType,
          id: '5',
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [coordinatorRepositoryProvider.overrideWithValue(repo)],
      child: localized((context) => localizedRouterApp(context, router)),
    ),
  );
  await tester.pumpAndSettle();
  _container = ProviderScope.containerOf(
    tester.element(find.text('page:home')),
  );
  if (openFromHome) {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }
}

Finder _inSheet(String text) =>
    find.descendant(of: find.byType(BottomSheet), matching: find.text(text));

Finder _inDialog(String text) =>
    find.descendant(of: find.byType(SacDialog), matching: find.text(text));

void main() {
  setUpAll(initCoordinatorTestLocalization);

  group('content', () {
    testWidgets('frosted top bar, member header, files and history',
        (tester) async {
      await _pumpDetail(tester, _FakeRepository(detail: _evidence()));

      final bar = tester.widget<SacTopBar>(find.byType(SacTopBar));
      expect(bar.frosted, isTrue);
      expect(bar.title, 'Revisar evidencia');

      expect(find.text('Ana Pérez'), findsWidgets);
      expect(
        find.text('Amigo · Requisito 1 · Club Orión · Conquistadores'),
        findsOneWidget,
      );
      expect(find.widgetWithText(SacBadge, 'Pendiente'), findsOneWidget);
      expect(find.widgetWithText(SacBadge, 'Clase'), findsOneWidget);
      expect(find.text('Enviado el 01/10/2026'), findsOneWidget);

      expect(find.text('Archivos (2)'), findsOneWidget);
      expect(find.text('informe.pdf'), findsOneWidget);
      // The image falls back to a placeholder when it cannot load.
      expect(find.byType(Image), findsOneWidget);

      expect(find.text('Historial'), findsOneWidget);
      expect(find.text('Enviada para revisión'), findsOneWidget);
      expect(find.text('Rechazada'), findsOneWidget);
      expect(find.text('Carlos Coordinador'), findsOneWidget);
      expect(find.text('Falta una foto'), findsOneWidget);
    });

    for (final (status, label, variant) in [
      (EvidenceReviewStatus.pending, 'Pendiente', SacBadgeVariant.accent),
      (EvidenceReviewStatus.approved, 'Aprobado', SacBadgeVariant.secondary),
      (EvidenceReviewStatus.rejected, 'Rechazado', SacBadgeVariant.error),
    ]) {
      testWidgets('status badge for ${status.name} is $label', (tester) async {
        await _pumpDetail(
          tester,
          _FakeRepository(detail: _evidence(status: status)),
        );

        final badge = tester.widget<SacBadge>(
          find.widgetWithText(SacBadge, label),
        );
        expect(badge.variant, variant);
      });
    }

    testWidgets('the back button leads out of the full-screen route',
        (tester) async {
      await _pumpDetail(tester, _FakeRepository(detail: _evidence()));

      await tester.tap(find.byType(SacBackButton));
      await tester.pumpAndSettle();

      expect(find.byType(EvidenceReviewDetailView), findsNothing);
      expect(find.text('page:home'), findsOneWidget);
    });
  });

  group('action bar', () {
    testWidgets('pending shows reject and approve, both at least 48 tall',
        (tester) async {
      await _pumpDetail(tester, _FakeRepository(detail: _evidence()));

      expect(find.byType(ApprovalActionBar), findsOneWidget);
      final reject = find.widgetWithText(SacButton, 'Rechazar');
      final approve = find.widgetWithText(SacButton, 'Aprobar');
      expect(reject, findsOneWidget);
      expect(approve, findsOneWidget);
      expect(tester.getSize(reject).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(approve).height, greaterThanOrEqualTo(48));
      // Equal widths so "Rechazar" never truncates on a phone.
      expect(
        tester.getSize(approve).width,
        closeTo(tester.getSize(reject).width, 0.01),
      );
      // The bar sits at the bottom of the screen.
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      expect(tester.getBottomLeft(approve).dy, greaterThan(screen.height - 80));
    });

    testWidgets('a validated evidence hides the action bar', (tester) async {
      await _pumpDetail(
        tester,
        _FakeRepository(
            detail: _evidence(status: EvidenceReviewStatus.approved)),
      );

      expect(find.byType(ApprovalActionBar), findsNothing);
      expect(find.text('Aprobar'), findsNothing);
      expect(find.text('Rechazar'), findsNothing);
    });

    testWidgets('a rejected evidence hides the action bar', (tester) async {
      await _pumpDetail(
        tester,
        _FakeRepository(
            detail: _evidence(status: EvidenceReviewStatus.rejected)),
      );

      expect(find.byType(ApprovalActionBar), findsNothing);
    });
  });

  group('reject', () {
    testWidgets('requires a reason: empty shows an inline error and stays open',
        (tester) async {
      final repo = _FakeRepository(detail: _evidence());
      await _pumpDetail(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(_inSheet('Rechazar evidencia'), findsOneWidget);

      // Confirm without writing anything.
      await tester.tap(_inSheet('Rechazar'));
      await tester.pumpAndSettle();

      expect(find.text('Escribe el motivo del rechazo'), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(repo.rejections, isEmpty);

      // Whitespace only is still empty.
      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.tap(_inSheet('Rechazar'));
      await tester.pumpAndSettle();
      expect(repo.rejections, isEmpty);
      expect(find.byType(BottomSheet), findsOneWidget);
    });

    testWidgets('cancelling the sheet sends nothing', (tester) async {
      final repo = _FakeRepository(detail: _evidence());
      await _pumpDetail(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
      await tester.pumpAndSettle();
      await tester.tap(_inSheet('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsNothing);
      expect(repo.rejections, isEmpty);
      expect(find.byType(EvidenceReviewDetailView), findsOneWidget);
    });

    testWidgets(
        'with a reason it rejects, shows feedback, refreshes and goes back',
        (tester) async {
      final repo = _FakeRepository(detail: _evidence());
      await _pumpDetail(tester, repo);
      // Keep the list/hub providers alive to observe their invalidation.
      final subs = [
        _container.listen(pendingEvidenceProvider(null), (_, __) {}),
        _container.listen(slaDashboardProvider, (_, __) {}),
      ];
      addTearDown(() {
        for (final s in subs) {
          s.close();
        }
      });
      await tester.pumpAndSettle();
      final pendingBefore = repo.pendingCalls;
      final slaBefore = repo.slaCalls;

      await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '  Falta la foto  ');
      await tester.tap(_inSheet('Rechazar'));
      await tester.pumpAndSettle();

      expect(repo.rejections, ['Falta la foto']);
      expect(find.text('Evidencia rechazada'), findsOneWidget);
      // Popped back to where the review started.
      expect(find.byType(EvidenceReviewDetailView), findsNothing);
      expect(find.text('page:home'), findsOneWidget);
      // List and hub counters were invalidated and reloaded.
      expect(repo.pendingCalls, greaterThan(pendingBefore));
      expect(repo.slaCalls, greaterThan(slaBefore));
    });

    testWidgets('a failed rejection keeps the screen and shows an error',
        (tester) async {
      final repo = _FakeRepository(detail: _evidence())
        ..actionFailure = const ServerFailure(message: 'boom 500 RBAC');
      await _pumpDetail(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Rechazar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Falta la foto');
      await tester.tap(_inSheet('Rechazar'));
      await tester.pumpAndSettle();

      expect(find.text('Error al rechazar'), findsOneWidget);
      expect(find.textContaining('boom'), findsNothing);
      expect(find.byType(EvidenceReviewDetailView), findsOneWidget);
      expect(find.byType(ApprovalActionBar), findsOneWidget);
    });
  });

  group('approve', () {
    testWidgets('cancelling the confirmation does NOT approve', (tester) async {
      final repo = _FakeRepository(detail: _evidence());
      await _pumpDetail(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Aprobar'));
      await tester.pumpAndSettle();
      expect(find.byType(SacDialog), findsOneWidget);

      await tester.tap(_inDialog('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.approvals, isEmpty);
      expect(find.byType(EvidenceReviewDetailView), findsOneWidget);
    });

    testWidgets('confirming approves, shows feedback and goes back',
        (tester) async {
      final repo = _FakeRepository(detail: _evidence());
      await _pumpDetail(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Aprobar'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Todo en orden');
      await tester.tap(_inDialog('Aprobar'));
      await tester.pumpAndSettle();

      expect(repo.approvals, ['Todo en orden']);
      expect(find.text('Evidencia aprobada correctamente'), findsOneWidget);
      expect(find.byType(EvidenceReviewDetailView), findsNothing);
      expect(find.text('page:home'), findsOneWidget);
    });

    testWidgets('an empty comment is sent as null', (tester) async {
      final repo = _FakeRepository(detail: _evidence());
      await _pumpDetail(tester, repo);

      await tester.tap(find.widgetWithText(SacButton, 'Aprobar'));
      await tester.pumpAndSettle();
      await tester.tap(_inDialog('Aprobar'));
      await tester.pumpAndSettle();

      expect(repo.approvals, [null]);
    });
  });

  group('loading and errors', () {
    testWidgets('loading shows a skeleton below the bar, no action bar',
        (tester) async {
      final never = Completer<EvidenceReviewItem>();
      useTallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            evidenceDetailProvider.overrideWith((ref, key) => never.future),
          ],
          child: localized(
            (context) => localizedApp(
              context,
              const EvidenceReviewDetailView(
                type: EvidenceReviewType.honor,
                id: '1',
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(SacTopBar), findsOneWidget);
      expect(find.byType(ApprovalActionBar), findsNothing);
      expect(find.byType(SacErrorState), findsNothing);
      expect(find.text('Ana Pérez'), findsNothing);

      never.complete(_evidence());
      await tester.pumpAndSettle();
    });

    testWidgets('a load failure is localized and retryable', (tester) async {
      var calls = 0;
      useTallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            evidenceDetailProvider.overrideWith((ref, key) async {
              calls++;
              throw Exception('Exception: connection reset (500)');
            }),
          ],
          child: localized(
            (context) => localizedApp(
              context,
              const EvidenceReviewDetailView(
                type: EvidenceReviewType.honor,
                id: '1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SacErrorState), findsOneWidget);
      expect(find.text('No pudimos cargar la evidencia'), findsOneWidget);
      expect(find.textContaining('connection reset'), findsNothing);
      expect(find.byType(ApprovalActionBar), findsNothing);

      final before = calls;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));
    });

    testWidgets('a 403 shows access restricted without retry', (tester) async {
      useTallSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            evidenceDetailProvider.overrideWith(
              (ref, key) async => throw const CoordinatorLoadException(
                'No tienes permiso',
                isForbidden: true,
              ),
            ),
          ],
          child: localized(
            (context) => localizedApp(
              context,
              const EvidenceReviewDetailView(
                type: EvidenceReviewType.honor,
                id: '1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acceso restringido'), findsOneWidget);
      final icon = tester.widget<HugeIcon>(
        find.descendant(
          of: find.byType(SacErrorState),
          matching: find.byType(HugeIcon),
        ),
      );
      expect(icon.icon, HugeIcons.strokeRoundedLockKey);
      expect(find.text('Reintentar'), findsNothing);
    });
  });

  group('history labels', () {
    test('map backend actions in any case', () {
      expect(evidenceHistoryKind('APPROVED'), EvidenceHistoryKind.approved);
      expect(evidenceHistoryKind('approved'), EvidenceHistoryKind.approved);
      expect(
          evidenceHistoryKind('CLUB_APPROVED'), EvidenceHistoryKind.approved);
      expect(evidenceHistoryKind('REJECTED'), EvidenceHistoryKind.rejected);
      expect(evidenceHistoryKind('submitted'), EvidenceHistoryKind.submitted);
      expect(
        evidenceHistoryKind('instructor_proposed'),
        EvidenceHistoryKind.instructorProposed,
      );
      expect(
        evidenceHistoryKind('instructor_set'),
        EvidenceHistoryKind.instructorSet,
      );
      expect(evidenceHistoryKind('EXPIRED'), EvidenceHistoryKind.other);
    });
  });
}
