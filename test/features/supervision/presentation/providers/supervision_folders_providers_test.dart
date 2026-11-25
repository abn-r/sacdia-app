import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_folder.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_folders_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_folders_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

import '../../../../support/riverpod_test_support.dart';

typedef _QueueResult = Either<Failure, SupervisionFolderQueuePage>;
typedef _DetailResult = Either<Failure, SupervisionFolderDetail>;
typedef _ActionResult = Either<Failure, Unit>;

SupervisionFolderQueueItem _item(String id) =>
    SupervisionFolderQueueItem(id: id, clubName: 'Club $id');

SupervisionFolderQueuePage _page(
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

class _QueueCall {
  _QueueCall(this.filter, this.page, this.limit);
  final SupervisionFolderQueueFilter filter;
  final int page;
  final int limit;
}

class _FakeRepo implements SupervisionFoldersRepository {
  final queueCalls = <_QueueCall>[];
  final detailCalls = <String>[];
  final actions = <String>[];
  final args = <String, Map<String, Object?>>{};

  Future<_QueueResult> Function(_QueueCall call) onQueue =
      (_) async => Right(_page([_item('1')]));
  Future<_DetailResult> Function(String id) onDetail =
      (id) async => Right(SupervisionFolderDetail(id: id));
  _ActionResult actionResult = const Right(unit);

  Duration? actionDelay;

  Future<_ActionResult> _act(String name, Map<String, Object?> a) async {
    actions.add(name);
    args[name] = a;
    if (actionDelay != null) await Future<void>.delayed(actionDelay!);
    return actionResult;
  }

  @override
  Future<_QueueResult> getQueue({
    SupervisionFolderQueueFilter filter =
        SupervisionFolderQueueFilter.needsReview,
    int page = 1,
    int limit = 25,
    RequestCancelToken? cancelToken,
  }) {
    final call = _QueueCall(filter, page, limit);
    queueCalls.add(call);
    return onQueue(call);
  }

  @override
  Future<_DetailResult> getFolder(String folderId,
      {RequestCancelToken? cancelToken}) {
    detailCalls.add(folderId);
    return onDetail(folderId);
  }

  @override
  Future<_ActionResult> evaluateSection(String folderId, String sectionId,
          {required int earnedPoints,
          String? notes,
          RequestCancelToken? cancelToken}) =>
      _act('evaluate', {
        'folderId': folderId,
        'sectionId': sectionId,
        'earnedPoints': earnedPoints,
        'notes': notes,
      });

  @override
  Future<_ActionResult> reopenSection(String folderId, String sectionId,
          {RequestCancelToken? cancelToken}) =>
      _act('reopen', {'folderId': folderId, 'sectionId': sectionId});

  @override
  Future<_ActionResult> confirmUnion(String folderId, String sectionId,
          {required bool approve,
          String? notes,
          RequestCancelToken? cancelToken}) =>
      _act('confirmUnion', {
        'folderId': folderId,
        'sectionId': sectionId,
        'approve': approve,
        'notes': notes,
      });

  @override
  Future<_ActionResult> closeFolder(String folderId,
          {RequestCancelToken? cancelToken}) =>
      _act('close', {'folderId': folderId});

  @override
  Future<_ActionResult> saveReviewerNote(String evidenceId, String? note,
          {RequestCancelToken? cancelToken}) =>
      _act('reviewerNote', {'evidenceId': evidenceId, 'note': note});
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeRepo repo;
  late int pendingCountsBuilds;

  setUp(() {
    repo = _FakeRepo();
    pendingCountsBuilds = 0;
  });

  ProviderContainer make({bool listenQueue = true}) {
    final c = createTestContainer(overrides: [
      supervisionFoldersRepositoryProvider.overrideWithValue(repo),
      supervisionPendingCountsProvider.overrideWith((ref) {
        pendingCountsBuilds++;
        return const SupervisionPendingCounts(territoryLevel: 'union');
      }),
    ]);
    c.listen(supervisionPendingCountsProvider, (a, b) {});
    if (listenQueue) c.listen(supervisionFoldersQueueProvider, (a, b) {});
    return c;
  }

  group('queue', () {
    test('first load starts in build with the default filter', () async {
      repo.onQueue =
          (_) async => Right(_page([_item('1'), _item('2')], total: 30));
      final c = make();
      expect(c.read(supervisionFoldersQueueProvider).isLoading, isTrue);
      await _settle();
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.isLoading, isFalse);
      expect(s.items.map((e) => e.id), ['1', '2']);
      expect(s.total, 30);
      expect(s.hasMore, isTrue);
      expect(s.error, isNull);
      expect(s.filter, SupervisionFolderQueueFilter.needsReview);
      expect(repo.queueCalls.single.filter,
          SupervisionFolderQueueFilter.needsReview);
      expect(repo.queueCalls.single.page, 1);
      expect(repo.queueCalls.single.limit, 25);
    });

    test('load failure keeps a SupervisionLoadException; 403 is forbidden',
        () async {
      repo.onQueue =
          (_) async => const Left(AuthFailure(message: 'nope', code: 403));
      final c = make();
      await _settle();
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.isLoading, isFalse);
      expect(s.error, isA<SupervisionLoadException>());
      expect(isForbiddenFailure(s.error!), isTrue);
    });

    test('refresh clears the error and reloads', () async {
      repo.onQueue =
          (_) async => const Left(ServerFailure(message: 'boom', code: 500));
      final c = make();
      await _settle();
      expect(c.read(supervisionFoldersQueueProvider).error, isNotNull);
      repo.onQueue = (_) async => Right(_page([_item('9')]));
      await c.read(supervisionFoldersQueueProvider.notifier).refresh();
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.error, isNull);
      expect(s.items.single.id, '9');
    });

    test('loadMore appends the next page and clears hasMore at the end',
        () async {
      repo.onQueue = (call) async => call.page == 1
          ? Right(_page([_item('1'), _item('2')], total: 3))
          : Right(_page([_item('3')], page: 2, total: 3));
      final c = make();
      await _settle();
      await c.read(supervisionFoldersQueueProvider.notifier).loadMore();
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.items.map((e) => e.id), ['1', '2', '3']);
      expect(s.hasMore, isFalse);
      expect(s.isLoadingMore, isFalse);
      expect(repo.queueCalls.last.page, 2);

      await c.read(supervisionFoldersQueueProvider.notifier).loadMore();
      expect(repo.queueCalls, hasLength(2));
    });

    test('loadMore skips duplicates already in the list', () async {
      repo.onQueue = (call) async => call.page == 1
          ? Right(_page([_item('1'), _item('2')], total: 4))
          : Right(_page([_item('2'), _item('3')], page: 2, total: 4));
      final c = make();
      await _settle();
      await c.read(supervisionFoldersQueueProvider.notifier).loadMore();
      expect(c.read(supervisionFoldersQueueProvider).items.map((e) => e.id),
          ['1', '2', '3']);
    });

    test('loadMore failure keeps items and reports the error', () async {
      repo.onQueue = (call) async => call.page == 1
          ? Right(_page([_item('1')], total: 5))
          : const Left(ServerFailure(message: 'boom', code: 500));
      final c = make();
      await _settle();
      await c.read(supervisionFoldersQueueProvider.notifier).loadMore();
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.items, hasLength(1));
      expect(s.isLoadingMore, isFalse);
      expect(s.error, isA<SupervisionLoadException>());
    });

    test('setFilter resets the list and requests the new filter', () async {
      final c = make();
      await _settle();
      repo.onQueue = (call) async => Right(_page([_item('9')], total: 1));
      c
          .read(supervisionFoldersQueueProvider.notifier)
          .setFilter(SupervisionFolderQueueFilter.evaluated);
      final loading = c.read(supervisionFoldersQueueProvider);
      expect(loading.items, isEmpty);
      expect(loading.isLoading, isTrue);
      expect(loading.hasMore, isFalse);
      expect(loading.filter, SupervisionFolderQueueFilter.evaluated);
      await _settle();
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.items.single.id, '9');
      expect(
          repo.queueCalls.last.filter, SupervisionFolderQueueFilter.evaluated);
      expect(repo.queueCalls.last.page, 1);
    });

    test('setFilter with the current filter does nothing', () async {
      final c = make();
      await _settle();
      c
          .read(supervisionFoldersQueueProvider.notifier)
          .setFilter(SupervisionFolderQueueFilter.needsReview);
      await _settle();
      expect(repo.queueCalls, hasLength(1));
    });

    test('stale first-page response is ignored', () async {
      final slow = Completer<_QueueResult>();
      var n = 0;
      repo.onQueue = (call) {
        n++;
        if (n == 1) return slow.future;
        return Future.value(Right(_page([_item('new')])));
      };
      final c = make();
      c
          .read(supervisionFoldersQueueProvider.notifier)
          .setFilter(SupervisionFolderQueueFilter.all);
      await _settle();
      slow.complete(Right(_page([_item('old')])));
      await _settle();
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.items.map((e) => e.id), ['new']);
      expect(s.filter, SupervisionFolderQueueFilter.all);
      expect(s.isLoading, isFalse);
    });

    test('stale loadMore response is ignored after a filter change', () async {
      final slowMore = Completer<_QueueResult>();
      repo.onQueue = (call) {
        if (call.page == 2) return slowMore.future;
        return Future.value(Right(_page([_item('1')], total: 10)));
      };
      final c = make();
      await _settle();
      final more = c.read(supervisionFoldersQueueProvider.notifier).loadMore();
      c
          .read(supervisionFoldersQueueProvider.notifier)
          .setFilter(SupervisionFolderQueueFilter.evaluated);
      await _settle();
      slowMore.complete(Right(_page([_item('late')], page: 2, total: 10)));
      await more;
      final s = c.read(supervisionFoldersQueueProvider);
      expect(s.items.map((e) => e.id), isNot(contains('late')));
      expect(s.isLoadingMore, isFalse);
    });

    test('an action keeps the selected filter after the queue reloads',
        () async {
      final c = make();
      await _settle();
      c
          .read(supervisionFoldersQueueProvider.notifier)
          .setFilter(SupervisionFolderQueueFilter.evaluated);
      await _settle();
      await c.read(supervisionFolderActionsProvider).closeFolder('f1');
      await _settle();
      expect(c.read(supervisionFoldersQueueProvider).filter,
          SupervisionFolderQueueFilter.evaluated);
      expect(
          repo.queueCalls.last.filter, SupervisionFolderQueueFilter.evaluated);
    });

    test('state copyWith can clear the error', () {
      const s = SupervisionFoldersQueueState(error: 'x');
      expect(s.copyWith(isLoading: true).error, 'x');
      expect(s.copyWith(error: null).error, isNull);
    });
  });

  group('detail', () {
    test('returns the folder', () async {
      final c = make();
      final d = await c.read(supervisionFolderDetailProvider('f1').future);
      expect(d.id, 'f1');
      expect(repo.detailCalls, ['f1']);
    });

    test('failure throws a SupervisionLoadException, 403 is forbidden',
        () async {
      repo.onDetail =
          (_) async => const Left(AuthFailure(message: 'no', code: 403));
      final c = make();
      final sub = c.listen(supervisionFolderDetailProvider('f1'), (a, b) {});
      await _settle();
      final state = c.read(supervisionFolderDetailProvider('f1'));
      expect(state.hasError, isTrue);
      expect(state.error, isA<SupervisionLoadException>());
      expect(isForbiddenFailure(state.error!), isTrue);
      sub.close();
    });
  });

  group('actions', () {
    int detailBuilds() => repo.detailCalls.length;

    test('evaluate success sends trimmed notes and invalidates', () async {
      final c = make();
      c.listen(supervisionFolderDetailProvider('f1'), (a, b) {});
      await _settle();
      final queueBefore = repo.queueCalls.length;
      final detailBefore = detailBuilds();
      final countsBefore = pendingCountsBuilds;

      final r = await c
          .read(supervisionFolderActionsProvider)
          .evaluateSection('f1', 's1', earnedPoints: 8, notes: '  good  ');
      await _settle();

      expect(r.ok, isTrue);
      expect(r.errorMessage, isNull);
      expect(r.errorCode, isNull);
      expect(repo.args['evaluate'], {
        'folderId': 'f1',
        'sectionId': 's1',
        'earnedPoints': 8,
        'notes': 'good',
      });
      expect(detailBuilds(), detailBefore + 1);
      expect(repo.queueCalls.length, queueBefore + 1);
      expect(pendingCountsBuilds, countsBefore + 1);
    });

    test('blank notes are omitted', () async {
      final c = make();
      final actions = c.read(supervisionFolderActionsProvider);
      await actions.evaluateSection('f1', 's1', earnedPoints: 1, notes: '   ');
      expect(repo.args['evaluate']!['notes'], isNull);
      await actions.confirmUnion('f1', 's1', approve: false, notes: '');
      expect(repo.args['confirmUnion'], {
        'folderId': 'f1',
        'sectionId': 's1',
        'approve': false,
        'notes': null,
      });
    });

    test('reopen, confirmUnion, close and reviewer note call the repo',
        () async {
      final c = make();
      final actions = c.read(supervisionFolderActionsProvider);
      expect((await actions.reopenSection('f1', 's1')).ok, isTrue);
      expect(repo.args['reopen'], {'folderId': 'f1', 'sectionId': 's1'});

      expect(
          (await actions.confirmUnion('f1', 's1', approve: true, notes: ' n '))
              .ok,
          isTrue);
      expect(repo.args['confirmUnion']!['approve'], isTrue);
      expect(repo.args['confirmUnion']!['notes'], 'n');

      expect((await actions.closeFolder('f1')).ok, isTrue);
      expect(repo.args['close'], {'folderId': 'f1'});

      expect((await actions.saveReviewerNote('f1', 'e1', ' note ')).ok, isTrue);
      expect(repo.args['reviewerNote'], {'evidenceId': 'e1', 'note': 'note'});
    });

    test('blank reviewer note is sent as null', () async {
      final c = make();
      final actions = c.read(supervisionFolderActionsProvider);
      await actions.saveReviewerNote('f1', 'e1', '   ');
      expect(repo.args['reviewerNote']!['note'], isNull);
      await actions.saveReviewerNote('f1', 'e1', null);
      expect(repo.args['reviewerNote']!['note'], isNull);
    });

    for (final name in const [
      'evaluate',
      'reopen',
      'confirmUnion',
      'close',
      'reviewerNote',
    ]) {
      test('$name invalidates detail, queue and pending counts', () async {
        final c = make();
        c.listen(supervisionFolderDetailProvider('f1'), (a, b) {});
        await _settle();
        final queueBefore = repo.queueCalls.length;
        final detailBefore = detailBuilds();
        final countsBefore = pendingCountsBuilds;
        final a = c.read(supervisionFolderActionsProvider);
        final r = switch (name) {
          'evaluate' => await a.evaluateSection('f1', 's1', earnedPoints: 1),
          'reopen' => await a.reopenSection('f1', 's1'),
          'confirmUnion' => await a.confirmUnion('f1', 's1', approve: true),
          'close' => await a.closeFolder('f1'),
          _ => await a.saveReviewerNote('f1', 'e1', 'x'),
        };
        await _settle();
        expect(r.ok, isTrue);
        expect(detailBuilds(), detailBefore + 1);
        expect(repo.queueCalls.length, queueBefore + 1);
        expect(pendingCountsBuilds, countsBefore + 1);
      });
    }

    test('error returns code and message and invalidates nothing', () async {
      repo.actionResult = const Left(ServerFailure(
        message: 'too many',
        code: 400,
        errorCode: 'ANNUAL_FOLDER_EARNED_POINTS_EXCEED_MAX',
      ));
      final c = make();
      c.listen(supervisionFolderDetailProvider('f1'), (a, b) {});
      await _settle();
      final queueBefore = repo.queueCalls.length;
      final detailBefore = detailBuilds();
      final countsBefore = pendingCountsBuilds;
      final r = await c
          .read(supervisionFolderActionsProvider)
          .evaluateSection('f1', 's1', earnedPoints: 99);
      await _settle();
      expect(r.ok, isFalse);
      expect(r.errorCode, 'ANNUAL_FOLDER_EARNED_POINTS_EXCEED_MAX');
      expect(r.errorMessage, 'too many');
      expect(detailBuilds(), detailBefore);
      expect(repo.queueCalls.length, queueBefore);
      expect(pendingCountsBuilds, countsBefore);
    });

    for (final code in const [
      'ANNUAL_FOLDER_STATUS_INVALID_FOR_EVALUATE',
      'ANNUAL_FOLDER_STATUS_INVALID_FOR_REOPEN',
      'ANNUAL_FOLDER_SECTION_TERMINAL',
      'ANNUAL_FOLDER_SECTION_NOT_PREAPPROVED',
      'ANNUAL_FOLDER_STATUS_CONFLICT',
      'ANNUAL_FOLDER_NOT_FOUND',
    ]) {
      test('$code invalidates the detail and still returns the error',
          () async {
        repo.actionResult =
            Left(ServerFailure(message: 'stale', code: 409, errorCode: code));
        final c = make();
        c.listen(supervisionFolderDetailProvider('f1'), (a, b) {});
        await _settle();
        final detailBefore = detailBuilds();
        final r = await c
            .read(supervisionFolderActionsProvider)
            .reopenSection('f1', 's1');
        await _settle();
        expect(r.ok, isFalse);
        expect(r.errorCode, code);
        expect(r.errorMessage, 'stale');
        expect(detailBuilds(), detailBefore + 1);
      });
    }

    test('403 on an action keeps the detail and surfaces the code', () async {
      repo.actionResult = const Left(AuthFailure(
        message: 'denied',
        code: 403,
        errorCode: 'ANNUAL_FOLDER_EVIDENCE_TERRITORY_DENIED',
      ));
      final c = make();
      c.listen(supervisionFolderDetailProvider('f1'), (a, b) {});
      await _settle();
      final detailBefore = detailBuilds();
      final r = await c
          .read(supervisionFolderActionsProvider)
          .saveReviewerNote('f1', 'e1', 'x');
      await _settle();
      expect(r.errorCode, 'ANNUAL_FOLDER_EVIDENCE_TERRITORY_DENIED');
      expect(detailBuilds(), detailBefore);
    });

    test('actions work when nobody listens to any provider', () async {
      final c = createTestContainer(overrides: [
        supervisionFoldersRepositoryProvider.overrideWithValue(repo),
        supervisionPendingCountsProvider.overrideWith(
            (ref) => const SupervisionPendingCounts(territoryLevel: 'union')),
      ]);
      repo.actionDelay = const Duration(milliseconds: 20);
      final actions = c.read(supervisionFolderActionsProvider);
      final result = await actions.closeFolder('f1');
      expect(result.ok, isTrue);
      expect(repo.actions, ['close']);
    });
  });
}
