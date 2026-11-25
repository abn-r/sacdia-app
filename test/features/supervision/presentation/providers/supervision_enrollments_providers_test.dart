import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_enrollment.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_pending_counts.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_enrollments_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_enrollments_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

import '../../../../support/riverpod_test_support.dart';

typedef _QueueResult = Either<Failure, SupervisionEnrollmentPage>;
typedef _ItemResult = Either<Failure, SupervisionEnrollment>;

SupervisionEnrollment _enr(String id,
        [SupervisionEnrollmentStatus status =
            SupervisionEnrollmentStatus.pendingValidation]) =>
    SupervisionEnrollment(id: id, status: status, clubName: 'Club $id');

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

class _Call {
  _Call(this.status, this.search, this.page);
  final SupervisionEnrollmentStatus status;
  final String? search;
  final int page;
}

class _FakeRepo implements SupervisionEnrollmentsRepository {
  final calls = <_Call>[];
  final approved = <String>[];
  final rejected = <String>[];

  Future<_QueueResult> Function(_Call call) onQueue =
      (_) async => Right(_page([_enr('1')]));
  Future<_ItemResult> Function(String id) onApprove =
      (id) async => Right(_enr(id, SupervisionEnrollmentStatus.active));
  Future<_ItemResult> Function(String id, String reason) onReject =
      (id, _) async => Right(_enr(id, SupervisionEnrollmentStatus.rejected));

  @override
  Future<_QueueResult> getQueue({
    SupervisionEnrollmentStatus status =
        SupervisionEnrollmentStatus.pendingValidation,
    String? search,
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  }) {
    final call = _Call(status, search, page);
    calls.add(call);
    return onQueue(call);
  }

  @override
  Future<_ItemResult> approve(String enrollmentId,
      {RequestCancelToken? cancelToken}) {
    approved.add(enrollmentId);
    return onApprove(enrollmentId);
  }

  @override
  Future<_ItemResult> reject(String enrollmentId, String reason,
      {RequestCancelToken? cancelToken}) {
    rejected.add(enrollmentId);
    return onReject(enrollmentId, reason);
  }
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

  ProviderContainer make() {
    final c = createTestContainer(overrides: [
      supervisionEnrollmentsRepositoryProvider.overrideWithValue(repo),
      supervisionPendingCountsProvider.overrideWith((ref) {
        pendingCountsBuilds++;
        return const SupervisionPendingCounts(territoryLevel: 'union');
      }),
    ]);
    c.listen(supervisionPendingCountsProvider, (a, b) {});
    c.listen(supervisionEnrollmentsProvider, (a, b) {});
    return c;
  }

  test('first load starts in build and fills the state', () async {
    repo.onQueue = (_) async => Right(_page([_enr('1'), _enr('2')], total: 30));
    final c = make();
    expect(c.read(supervisionEnrollmentsProvider).isLoading, isTrue);
    await _settle();
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.isLoading, isFalse);
    expect(s.items.map((e) => e.id), ['1', '2']);
    expect(s.total, 30);
    expect(s.hasMore, isTrue);
    expect(s.counts!.pending, 5);
    expect(s.error, isNull);
    expect(repo.calls.single.status,
        SupervisionEnrollmentStatus.pendingValidation);
    expect(repo.calls.single.page, 1);
  });

  test('load failure keeps a SupervisionLoadException; 403 is forbidden',
      () async {
    repo.onQueue =
        (_) async => const Left(AuthFailure(message: 'nope', code: 403));
    final c = make();
    await _settle();
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.isLoading, isFalse);
    expect(s.error, isA<SupervisionLoadException>());
    expect(isForbiddenFailure(s.error!), isTrue);
  });

  test('loadMore appends the next page and clears hasMore at the end',
      () async {
    repo.onQueue = (call) async => call.page == 1
        ? Right(_page([_enr('1'), _enr('2')], total: 3))
        : Right(_page([_enr('3')], page: 2, total: 3));
    final c = make();
    await _settle();
    await c.read(supervisionEnrollmentsProvider.notifier).loadMore();
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items.map((e) => e.id), ['1', '2', '3']);
    expect(s.hasMore, isFalse);
    expect(s.isLoadingMore, isFalse);
    expect(repo.calls.last.page, 2);

    await c.read(supervisionEnrollmentsProvider.notifier).loadMore();
    expect(repo.calls, hasLength(2));
  });

  test('loadMore failure keeps items and reports the error', () async {
    repo.onQueue = (call) async => call.page == 1
        ? Right(_page([_enr('1')], total: 5))
        : const Left(ServerFailure(message: 'boom', code: 500));
    final c = make();
    await _settle();
    await c.read(supervisionEnrollmentsProvider.notifier).loadMore();
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items, hasLength(1));
    expect(s.isLoadingMore, isFalse);
    expect(s.error, isA<SupervisionLoadException>());
  });

  test('setFilter resets the list and requests the new status', () async {
    final c = make();
    await _settle();
    repo.onQueue = (call) async =>
        Right(_page([_enr('9', SupervisionEnrollmentStatus.active)], total: 1));
    c
        .read(supervisionEnrollmentsProvider.notifier)
        .setFilter(SupervisionEnrollmentStatus.active);
    final loading = c.read(supervisionEnrollmentsProvider);
    expect(loading.items, isEmpty);
    expect(loading.isLoading, isTrue);
    expect(loading.filter, SupervisionEnrollmentStatus.active);
    await _settle();
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items.single.id, '9');
    expect(repo.calls.last.status, SupervisionEnrollmentStatus.active);
    expect(repo.calls.last.page, 1);
  });

  test('setSearch resets the list and sends the term', () async {
    final c = make();
    await _settle();
    c.read(supervisionEnrollmentsProvider.notifier).setSearch(' orion ');
    expect(c.read(supervisionEnrollmentsProvider).items, isEmpty);
    await _settle();
    expect(repo.calls.last.search, 'orion');
    expect(c.read(supervisionEnrollmentsProvider).search, 'orion');
  });

  test('stale first-page response is ignored', () async {
    final slow = Completer<_QueueResult>();
    var n = 0;
    repo.onQueue = (call) {
      n++;
      if (n == 1) return slow.future;
      return Future.value(
          Right(_page([_enr('new', SupervisionEnrollmentStatus.rejected)])));
    };
    final c = make();
    c
        .read(supervisionEnrollmentsProvider.notifier)
        .setFilter(SupervisionEnrollmentStatus.rejected);
    await _settle();
    slow.complete(Right(_page([_enr('old')])));
    await _settle();
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items.map((e) => e.id), ['new']);
    expect(s.filter, SupervisionEnrollmentStatus.rejected);
    expect(s.isLoading, isFalse);
  });

  test('stale loadMore response is ignored after a filter change', () async {
    final slowMore = Completer<_QueueResult>();
    repo.onQueue = (call) {
      if (call.page == 2) return slowMore.future;
      return Future.value(Right(_page([_enr('1')], total: 10)));
    };
    final c = make();
    await _settle();
    final more = c.read(supervisionEnrollmentsProvider.notifier).loadMore();
    c
        .read(supervisionEnrollmentsProvider.notifier)
        .setFilter(SupervisionEnrollmentStatus.active);
    await _settle();
    slowMore.complete(Right(_page([_enr('late')], page: 2, total: 10)));
    await more;
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items.map((e) => e.id), isNot(contains('late')));
    expect(s.isLoadingMore, isFalse);
  });

  test('approve success removes the item, updates counts and invalidates',
      () async {
    repo.onQueue = (_) async => Right(_page([_enr('1'), _enr('2')], total: 2));
    final c = make();
    await _settle();
    final builds = pendingCountsBuilds;
    final result =
        await c.read(supervisionEnrollmentsProvider.notifier).approve('1');
    expect(result, isNull);
    await _settle();
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items.map((e) => e.id), ['2']);
    expect(s.total, 1);
    expect(s.counts!.pending, 4);
    expect(s.counts!.approved, 3);
    expect(s.counts!.rejected, 1);
    expect(s.lastActionErrorCode, isNull);
    expect(repo.approved, ['1']);
    expect(pendingCountsBuilds, builds + 1);
  });

  test('reject success removes the item and bumps rejected', () async {
    final c = make();
    await _settle();
    final result = await c
        .read(supervisionEnrollmentsProvider.notifier)
        .reject('1', 'Missing board');
    expect(result, isNull);
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items, isEmpty);
    expect(s.counts!.pending, 4);
    expect(s.counts!.approved, 2);
    expect(s.counts!.rejected, 2);
    expect(repo.rejected, ['1']);
  });

  test('item stays (updated) when the result still matches the filter',
      () async {
    repo.onQueue = (_) async =>
        Right(_page([_enr('1', SupervisionEnrollmentStatus.active)], total: 1));
    final c = make();
    c
        .read(supervisionEnrollmentsProvider.notifier)
        .setFilter(SupervisionEnrollmentStatus.active);
    await _settle();
    expect(await c.read(supervisionEnrollmentsProvider.notifier).approve('1'),
        isNull);
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.items, hasLength(1));
    expect(s.counts!.pending, 5);
  });

  test('business error returns the message and sets lastActionErrorCode',
      () async {
    repo.onApprove = (_) async => const Left(AuthFailure(
        message: 'own club', code: 403, errorCode: 'CE_SELF_REVIEW'));
    final c = make();
    await _settle();
    final result =
        await c.read(supervisionEnrollmentsProvider.notifier).approve('1');
    expect(result, 'own club');
    final s = c.read(supervisionEnrollmentsProvider);
    expect(s.lastActionErrorCode, 'CE_SELF_REVIEW');
    expect(s.items, hasLength(1));
    expect(repo.calls, hasLength(1));
    expect(pendingCountsBuilds, 1);
  });

  for (final code in const [
    'CE_ENROLLMENT_NOT_PENDING',
    'CE_ENROLLMENT_NOT_FOUND',
  ]) {
    test('$code triggers a refresh and still returns the message', () async {
      repo.onReject = (a, b) async =>
          Left(ServerFailure(message: 'stale', code: 409, errorCode: code));
      final c = make();
      await _settle();
      repo.onQueue = (_) async => Right(_page([_enr('7')], total: 1));
      final result = await c
          .read(supervisionEnrollmentsProvider.notifier)
          .reject('1', 'because');
      expect(result, 'stale');
      expect(repo.calls, hasLength(2));
      final s = c.read(supervisionEnrollmentsProvider);
      expect(s.items.map((e) => e.id), ['7']);
      expect(s.lastActionErrorCode, code);
    });
  }

  test('actions work when nobody listens to the provider', () async {
    repo.onApprove = (id) async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return Right(_enr(id, SupervisionEnrollmentStatus.active));
    };
    final c = createTestContainer(overrides: [
      supervisionEnrollmentsRepositoryProvider.overrideWithValue(repo),
    ]);
    final notifier = c.read(supervisionEnrollmentsProvider.notifier);
    final result = await notifier.approve('1');
    expect(result, isNull);
    expect(repo.approved, ['1']);
  });
}

typedef ProviderContainerHandle = dynamic;
