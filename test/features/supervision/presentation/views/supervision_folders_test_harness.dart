/// Harness for the annual-folder views (queue and detail): a fake
/// [SupervisionFoldersRepository] that records every call, builders for the
/// entities, and a pump with a router that has a landing route for
/// `/supervision/folders/:folderId`.
///
/// Reuses the user, auth fake and localization setup of
/// `supervision_view_test_harness.dart` (read only).
library;

import 'package:dartz/dartz.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_folders_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_folders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../../coordinator/coordinator_test_harness.dart';
import 'supervision_view_test_harness.dart';

const kEvaluateCap = 'folders.evaluate';
const kConfirmUnionCap = 'folders.confirm_union';

typedef QueueResult = Either<Failure, SupervisionFolderQueuePage>;
typedef FolderResult = Either<Failure, SupervisionFolderDetail>;
typedef ActionResult = Either<Failure, Unit>;

const ServerFailure kBoom = ServerFailure(message: 'boom');

ServerFailure codedFailure(String code, [String message = 'server says no']) =>
    ServerFailure(message: message, errorCode: code);

// ── Builders ────────────────────────────────────────────────────────────────

SupervisionFolderQueueItem queueItem(
  String id, {
  String? displayName,
  String clubName = '',
  String clubTypeName = 'Conquistadores',
  String localFieldName = 'Asociación Norte',
  List<String> pending = const [],
  SupervisionFolderStatus status = SupervisionFolderStatus.submitted,
  DateTime? latestSubmittedAt,
}) =>
    SupervisionFolderQueueItem(
      id: id,
      displayName: displayName ?? 'Carpeta $id',
      clubName: clubName,
      clubTypeName: clubTypeName,
      localFieldName: localFieldName,
      folderStatus: status,
      pendingSectionNames: pending,
      latestSubmittedAt: latestSubmittedAt,
    );

SupervisionFolderQueuePage queuePage(
  List<SupervisionFolderQueueItem> items, {
  int page = 1,
  int? total,
}) =>
    SupervisionFolderQueuePage(
      items: items,
      total: total ?? items.length,
      page: page,
      limit: kSupervisionFoldersPageSize,
    );

SupervisionFolderEvidence evidence(
  String id, {
  String? fileName,
  String? reviewerNote,
}) =>
    SupervisionFolderEvidence(
      id: id,
      // PDF: the gallery renders a file tile, never a network image.
      fileUrl: 'https://files.example.com/$id.pdf',
      fileName: fileName ?? '$id.pdf',
      reviewerNote: reviewerNote,
    );

SupervisionFolderSection section(
  String id, {
  String? name,
  SupervisionSectionStatus status = SupervisionSectionStatus.submitted,
  int maxPoints = 100,
  int? earnedPoints,
  String? description,
  String? evaluationNotes,
  String? lfApproverName,
  DateTime? lfApprovedAt,
  String? unionApproverName,
  DateTime? unionApprovedAt,
  List<SupervisionFolderEvidence> evidences = const [],
}) =>
    SupervisionFolderSection(
      id: id,
      name: name ?? 'Sección $id',
      description: description,
      maxPoints: maxPoints,
      status: status,
      earnedPoints: earnedPoints,
      evaluationNotes: evaluationNotes,
      lfApproverName: lfApproverName,
      lfApprovedAt: lfApprovedAt,
      unionApproverName: unionApproverName,
      unionApprovedAt: unionApprovedAt,
      evidences: evidences,
    );

SupervisionFolderDetail folderDetail({
  String id = 'f1',
  SupervisionFolderStatus status = SupervisionFolderStatus.submitted,
  String clubName = 'Club Orión',
  String clubTypeName = 'Conquistadores',
  String yearLabel = '2026',
  String localFieldName = 'Asociación Norte',
  String templateName = 'Plantilla 2026',
  int totalEarnedPoints = 40,
  int totalMaxPoints = 100,
  double progressPercentage = 40,
  bool requiresUnionConfirmation = false,
  DateTime? submittedAt,
  List<SupervisionFolderSection>? sections,
}) =>
    SupervisionFolderDetail(
      id: id,
      status: status,
      clubName: clubName,
      clubTypeName: clubTypeName,
      yearLabel: yearLabel,
      localFieldName: localFieldName,
      templateName: templateName,
      totalEarnedPoints: totalEarnedPoints,
      totalMaxPoints: totalMaxPoints,
      progressPercentage: progressPercentage,
      requiresUnionConfirmation: requiresUnionConfirmation,
      submittedAt: submittedAt,
      sections: sections ?? [section('s1')],
    );

// ── Fake repository ─────────────────────────────────────────────────────────

class QueueCall {
  QueueCall(this.filter, this.page);
  final SupervisionFolderQueueFilter filter;
  final int page;
}

typedef EvaluateCall = ({
  String folderId,
  String sectionId,
  int points,
  String? notes,
});
typedef ConfirmCall = ({
  String folderId,
  String sectionId,
  bool approve,
  String? notes,
});
typedef NoteCall = ({String evidenceId, String? note});

class FakeFoldersRepo implements SupervisionFoldersRepository {
  final queueCalls = <QueueCall>[];
  final folderCalls = <String>[];
  final evaluateCalls = <EvaluateCall>[];
  final reopenCalls = <({String folderId, String sectionId})>[];
  final confirmCalls = <ConfirmCall>[];
  final closeCalls = <String>[];
  final noteCalls = <NoteCall>[];

  Future<QueueResult> Function(QueueCall call) onQueue =
      (_) async => Right(queuePage([queueItem('1')]));
  Future<FolderResult> Function(String id) onFolder =
      (_) async => Right(folderDetail());

  Future<ActionResult> Function()? onEvaluate;
  Future<ActionResult> Function()? onReopen;
  Future<ActionResult> Function()? onConfirm;
  Future<ActionResult> Function()? onClose;
  Future<ActionResult> Function()? onNote;

  static Future<ActionResult> _ok() async => const Right(unit);

  @override
  Future<QueueResult> getQueue({
    SupervisionFolderQueueFilter filter =
        SupervisionFolderQueueFilter.needsReview,
    int page = 1,
    int limit = 25,
    RequestCancelToken? cancelToken,
  }) {
    final call = QueueCall(filter, page);
    queueCalls.add(call);
    return onQueue(call);
  }

  @override
  Future<FolderResult> getFolder(
    String folderId, {
    RequestCancelToken? cancelToken,
  }) {
    folderCalls.add(folderId);
    return onFolder(folderId);
  }

  @override
  Future<ActionResult> evaluateSection(
    String folderId,
    String sectionId, {
    required int earnedPoints,
    String? notes,
    RequestCancelToken? cancelToken,
  }) {
    evaluateCalls.add((
      folderId: folderId,
      sectionId: sectionId,
      points: earnedPoints,
      notes: notes,
    ));
    return (onEvaluate ?? _ok)();
  }

  @override
  Future<ActionResult> reopenSection(
    String folderId,
    String sectionId, {
    RequestCancelToken? cancelToken,
  }) {
    reopenCalls.add((folderId: folderId, sectionId: sectionId));
    return (onReopen ?? _ok)();
  }

  @override
  Future<ActionResult> confirmUnion(
    String folderId,
    String sectionId, {
    required bool approve,
    String? notes,
    RequestCancelToken? cancelToken,
  }) {
    confirmCalls.add((
      folderId: folderId,
      sectionId: sectionId,
      approve: approve,
      notes: notes,
    ));
    return (onConfirm ?? _ok)();
  }

  @override
  Future<ActionResult> closeFolder(
    String folderId, {
    RequestCancelToken? cancelToken,
  }) {
    closeCalls.add(folderId);
    return (onClose ?? _ok)();
  }

  @override
  Future<ActionResult> saveReviewerNote(
    String evidenceId,
    String? note, {
    RequestCancelToken? cancelToken,
  }) {
    noteCalls.add((evidenceId: evidenceId, note: note));
    return (onNote ?? _ok)();
  }
}

// ── Pump ────────────────────────────────────────────────────────────────────

/// Pumps [home] at `/` with `/supervision/folders/:folderId` as a landing
/// route that renders `detail:<id>`.
Future<void> pumpFoldersApp(
  WidgetTester tester, {
  required Widget home,
  required FakeFoldersRepo repo,
  List<String> capabilities = const [kSupervisionAppView],
  Size? size,
  double? textScale,
  bool settle = true,
}) async {
  if (size != null) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  } else {
    useTallSurface(tester);
  }
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(
        path: '/supervision/folders/:folderId',
        builder: (_, state) =>
            Text('detail:${state.pathParameters['folderId']}'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    testProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(
          () => FakeSupervisionAuthNotifier(
            supervisionUser(capabilities: capabilities),
          ),
        ),
        supervisionFoldersRepositoryProvider.overrideWithValue(repo),
        supervisionPendingCountsProvider.overrideWith(
          (ref) async =>
              const SupervisionPendingCounts(territoryLevel: 'union'),
        ),
      ],
      child: localized(
        (context) => MaterialApp.router(
          routerConfig: router,
          locale: context.locale,
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(
              disableAnimations: true,
              textScaler:
                  textScale == null ? null : TextScaler.linear(textScale),
            ),
            child: child!,
          ),
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}
