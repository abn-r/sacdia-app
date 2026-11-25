import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_club.dart';
import 'package:sacdia_app/features/supervision/domain/repositories/supervision_clubs_repository.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_clubs_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';

import '../../../../support/riverpod_test_support.dart';

typedef _PageResult = Either<Failure, SupervisionClubPage>;

SupervisionClubListItem _item(int id) => SupervisionClubListItem(
      id: id,
      name: 'Club $id',
      active: true,
      churchName: '',
      districtName: '',
      localFieldName: '',
      sections: const [],
    );

SupervisionClubPage _page(
  List<int> ids, {
  int page = 1,
  int? total,
  bool hasMore = false,
}) =>
    SupervisionClubPage(
      items: ids.map(_item).toList(),
      page: page,
      total: total ?? ids.length,
      hasMore: hasMore,
    );

class _Call {
  _Call(this.filter, this.search, this.page, this.limit);
  final SupervisionClubActiveFilter filter;
  final String search;
  final int page;
  final int limit;
}

class _FakeRepo implements SupervisionClubsRepository {
  final calls = <_Call>[];
  Future<_PageResult> Function(_Call call) onClubs =
      (_) async => Right(_page([1]));

  @override
  Future<_PageResult> getClubs({
    required SupervisionClubActiveFilter filter,
    required String search,
    required int page,
    required int limit,
    RequestCancelToken? cancelToken,
  }) {
    final call = _Call(filter, search, page, limit);
    calls.add(call);
    return onClubs(call);
  }

  Future<Either<Failure, SupervisionClubSummary>> Function(int id) onSummary =
      (id) async => const Left(ServerFailure(message: 'unset'));

  @override
  Future<Either<Failure, SupervisionClubSummary>> getClubSummary(int clubId,
          {RequestCancelToken? cancelToken}) =>
      onSummary(clubId);
}

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late _FakeRepo repo;

  setUp(() => repo = _FakeRepo());

  ProviderContainer make({bool listen = true}) {
    final c = createTestContainer(overrides: [
      supervisionClubsRepositoryProvider.overrideWithValue(repo),
    ]);
    if (listen) c.listen(supervisionClubsProvider, (a, b) {});
    return c;
  }

  group('list', () {
    test('first page loads in build', () async {
      repo.onClubs =
          (_) async => Right(_page([1, 2], total: 30, hasMore: true));
      final c = make();
      expect(c.read(supervisionClubsProvider).isLoading, isTrue);
      await _settle();
      final s = c.read(supervisionClubsProvider);
      expect(s.isLoading, isFalse);
      expect(s.items.map((e) => e.id), [1, 2]);
      expect(s.total, 30);
      expect(s.hasMore, isTrue);
      expect(s.error, isNull);
      expect(repo.calls.single.page, 1);
      expect(repo.calls.single.limit, kSupervisionClubsPageSize);
      expect(repo.calls.single.filter, SupervisionClubActiveFilter.all);
      expect(repo.calls.single.search, '');
    });

    test('first page failure sets a SupervisionLoadException', () async {
      repo.onClubs =
          (_) async => const Left(AuthFailure(message: 'nope', code: 403));
      final c = make();
      await _settle();
      final s = c.read(supervisionClubsProvider);
      expect(s.isLoading, isFalse);
      expect(s.error, isA<SupervisionLoadException>());
      expect((s.error as SupervisionLoadException).isForbidden, isTrue);
    });

    test('loadMore appends, dedupes and stops when no more', () async {
      repo.onClubs = (call) async => call.page == 1
          ? Right(_page([1, 2], total: 4, hasMore: true))
          : Right(_page([2, 3, 4], page: 2, total: 4));
      final c = make();
      await _settle();
      await c.read(supervisionClubsProvider.notifier).loadMore();
      final s = c.read(supervisionClubsProvider);
      expect(s.items.map((e) => e.id), [1, 2, 3, 4]);
      expect(s.hasMore, isFalse);
      expect(repo.calls.last.page, 2);
      await c.read(supervisionClubsProvider.notifier).loadMore();
      expect(repo.calls, hasLength(2));
    });

    test('loadMore failure keeps items and sets the error', () async {
      repo.onClubs = (call) async => call.page == 1
          ? Right(_page([1, 2], total: 9, hasMore: true))
          : const Left(ServerFailure(message: 'boom', code: 500));
      final c = make();
      await _settle();
      await c.read(supervisionClubsProvider.notifier).loadMore();
      final s = c.read(supervisionClubsProvider);
      expect(s.items.map((e) => e.id), [1, 2]);
      expect(s.isLoadingMore, isFalse);
      expect(s.hasMore, isTrue);
      expect(s.error, isA<SupervisionLoadException>());
    });

    test('loadMore is a no-op while loading', () async {
      final gate = Completer<_PageResult>();
      repo.onClubs = (_) => gate.future;
      final c = make();
      await c.read(supervisionClubsProvider.notifier).loadMore();
      expect(repo.calls, hasLength(1));
      gate.complete(Right(_page([1])));
    });

    test('setFilter reloads at once and keeps items visible', () async {
      final gate = Completer<_PageResult>();
      repo.onClubs = (call) {
        if (call.filter == SupervisionClubActiveFilter.inactive) {
          return gate.future;
        }
        return Future.value(Right(_page([1, 2])));
      };
      final c = make();
      await _settle();
      final n = c.read(supervisionClubsProvider.notifier);
      n.setFilter(SupervisionClubActiveFilter.inactive);
      var s = c.read(supervisionClubsProvider);
      expect(s.filter, SupervisionClubActiveFilter.inactive);
      expect(s.isLoading, isTrue);
      expect(s.items.map((e) => e.id), [1, 2]);
      expect(repo.calls.last.filter, SupervisionClubActiveFilter.inactive);
      gate.complete(Right(_page([9])));
      await _settle();
      s = c.read(supervisionClubsProvider);
      expect(s.items.map((e) => e.id), [9]);
      expect(s.isLoading, isFalse);
      // Same filter again does nothing.
      n.setFilter(SupervisionClubActiveFilter.inactive);
      expect(repo.calls, hasLength(2));
    });

    test('setSearch debounces, trims and ignores unchanged values', () async {
      final c = make();
      await _settle();
      final n = c.read(supervisionClubsProvider.notifier);
      n.setSearch('o');
      n.setSearch('or');
      n.setSearch('  ori ');
      expect(c.read(supervisionClubsProvider).search, 'ori');
      expect(c.read(supervisionClubsProvider).isLoading, isTrue);
      expect(repo.calls, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(repo.calls, hasLength(1));
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _settle();
      expect(repo.calls, hasLength(2));
      expect(repo.calls.last.search, 'ori');
      expect(repo.calls.last.page, 1);
      expect(c.read(supervisionClubsProvider).isLoading, isFalse);
      n.setSearch('ori');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(repo.calls, hasLength(2));
    });

    test('stale generation response is dropped', () async {
      final first = Completer<_PageResult>();
      final second = Completer<_PageResult>();
      repo.onClubs = (call) => call.filter == SupervisionClubActiveFilter.all
          ? first.future
          : second.future;
      final c = make();
      c
          .read(supervisionClubsProvider.notifier)
          .setFilter(SupervisionClubActiveFilter.active);
      second.complete(Right(_page([2])));
      await _settle();
      first.complete(Right(_page([1])));
      await _settle();
      final s = c.read(supervisionClubsProvider);
      expect(s.items.map((e) => e.id), [2]);
      expect(s.filter, SupervisionClubActiveFilter.active);
    });

    test('refresh keeps items until the response arrives', () async {
      final c = make();
      await _settle();
      final gate = Completer<_PageResult>();
      repo.onClubs = (_) => gate.future;
      final f = c.read(supervisionClubsProvider.notifier).refresh();
      expect(c.read(supervisionClubsProvider).isLoading, isTrue);
      expect(c.read(supervisionClubsProvider).items, isNotEmpty);
      gate.complete(Right(_page([7])));
      await f;
      expect(c.read(supervisionClubsProvider).items.map((e) => e.id), [7]);
    });

    test('filter and search survive invalidate', () async {
      final c = make();
      await _settle();
      final n = c.read(supervisionClubsProvider.notifier);
      n.setFilter(SupervisionClubActiveFilter.active);
      n.setSearch('xy');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _settle();
      c.invalidate(supervisionClubsProvider);
      await _settle();
      final s = c.read(supervisionClubsProvider);
      expect(s.filter, SupervisionClubActiveFilter.active);
      expect(s.search, 'xy');
      expect(repo.calls.last.filter, SupervisionClubActiveFilter.active);
      expect(repo.calls.last.search, 'xy');
    });

    test('methods called without listening do not throw', () async {
      repo.onClubs = (call) async => Right(_page([call.page]));
      final c = make(listen: false);
      final n = c.read(supervisionClubsProvider.notifier);
      // No listener: the debounce and the loads must hold the provider alive.
      n.setFilter(SupervisionClubActiveFilter.active);
      n.setSearch('abc');
      await Future<void>.delayed(const Duration(milliseconds: 450));
      await _settle();
      expect(repo.calls.last.search, 'abc');
      expect(repo.calls.last.filter, SupervisionClubActiveFilter.active);
      final before = repo.calls.length;
      final c2 = make(listen: false);
      await c2.read(supervisionClubsProvider.notifier).refresh();
      expect(repo.calls.length, greaterThan(before));
    });
  });

  group('summary', () {
    const summary = SupervisionClubSummary(
      profile: SupervisionClubProfile(
        id: 3,
        name: 'Orion',
        active: true,
        description: null,
        address: null,
        churchName: '',
        districtName: '',
        localFieldName: '',
        sections: [],
      ),
      overview: null,
      leadership: null,
    );

    test('returns the summary by club id', () async {
      repo.onSummary = (id) async => id == 3 ? const Right(summary) : throw id;
      final c = make(listen: false);
      expect(await c.read(supervisionClubSummaryProvider(3).future), summary);
    });

    test('403 becomes a forbidden SupervisionLoadException', () async {
      repo.onSummary =
          (_) async => const Left(AuthFailure(message: 'no', code: 403));
      final c = make(listen: false);
      Object? error;
      try {
        await c.read(supervisionClubSummaryProvider(3).future);
      } catch (e) {
        error = e;
      }
      expect(error, isA<SupervisionLoadException>());
      expect((error as SupervisionLoadException).isForbidden, isTrue);
    });
  });
}
