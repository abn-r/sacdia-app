import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/members/domain/entities/role_candidate.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/members/presentation/providers/role_candidates_providers.dart';

import '../../../../support/riverpod_test_support.dart';
import '../../members_test_support.dart';
import '../../role_candidates_test_support.dart';

void main() {
  late FakeMembersRepository repo;

  setUp(() => repo = FakeMembersRepository());

  RoleCandidatesQuery query({
    RoleCandidatesFilter filter = RoleCandidatesFilter.available,
    String search = '',
  }) =>
      RoleCandidatesQuery(
        clubId: 1,
        sectionId: 163,
        filter: filter,
        search: search,
      );

  test('loads the first page with the query filter and search', () async {
    repo.roleCandidatesResults = [
      Right(candidatesPage([candidate(id: 'a'), candidate(id: 'b')])),
    ];
    final container = createTestContainer(
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
    );

    final provider = roleCandidatesProvider(
      query(filter: RoleCandidatesFilter.withRole, search: 'lau'),
    );
    final state = await container.read(provider.future);

    expect(state.items.map((i) => i.userId), ['a', 'b']);
    expect(state.slots, hasLength(5));
    expect(state.counts.available, 4);
    expect(state.hasMore, isFalse);
    final call = repo.roleCandidateCalls.single;
    expect(call.clubId, 1);
    expect(call.sectionId, 163);
    expect(call.filter, RoleCandidatesFilter.withRole);
    expect(call.search, 'lau');
    expect(call.page, 1);
  });

  test('loadMore appends the next page and skips repeated people', () async {
    repo.roleCandidatesResults = [
      Right(candidatesPage(
        [for (var i = 0; i < 20; i++) candidate(id: 'p1-$i')],
        total: 22,
      )),
      Right(candidatesPage(
        [candidate(id: 'p1-19'), candidate(id: 'p2-0'), candidate(id: 'p2-1')],
        total: 22,
        page: 2,
      )),
    ];
    final container = createTestContainer(
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
    );
    final provider = roleCandidatesProvider(query());

    final first = await container.read(provider.future);
    expect(first.items, hasLength(20));
    expect(first.hasMore, isTrue);

    // Nobody listens to the provider: loadMore must survive that.
    await container.read(provider.notifier).loadMore();

    final state = container.read(provider).requireValue;
    expect(repo.roleCandidateCalls.last.page, 2);
    expect(state.items.map((i) => i.userId).toList().sublist(19),
        ['p1-19', 'p2-0', 'p2-1']);
    expect(state.items, hasLength(22), reason: 'p1-19 is not duplicated');
    expect(state.hasMore, isFalse);
    expect(state.isLoadingMore, isFalse);
  });

  test('a failed page keeps the list and flags the failure', () async {
    repo.roleCandidatesResults = [
      Right(candidatesPage(
        [for (var i = 0; i < 20; i++) candidate(id: 'p1-$i')],
        total: 40,
      )),
      const Left(ServerFailure(message: 'boom', code: 500)),
    ];
    final container = createTestContainer(
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
    );
    final provider = roleCandidatesProvider(query());
    await container.read(provider.future);

    await container.read(provider.notifier).loadMore();

    final state = container.read(provider).requireValue;
    expect(state.items, hasLength(20));
    expect(state.loadMoreFailed, isTrue);
    expect(state.isLoadingMore, isFalse);
    expect(state.hasMore, isTrue);
  });

  test('a failure on the first page is the original Failure (404 kept)',
      () async {
    repo.roleCandidatesResults = [
      const Left(ServerFailure(message: 'no section', code: 404)),
    ];
    final container = createTestContainer(
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
    );
    final provider = roleCandidatesProvider(query());

    // Keep the provider alive: an unlistened autoDispose one is dropped.
    container.listen(provider, (_, __) {});
    await expectLater(container.read(provider.future), throwsA(isA<Failure>()));

    final error = container.read(provider).error as Failure;
    expect(error.code, 404);
  });

  test('another filter is another list', () async {
    repo.roleCandidatesResults = [
      Right(candidatesPage([candidate(id: 'a')])),
      Right(candidatesPage([
        candidate(id: 'b', group: RoleCandidateGroup.withRole),
      ])),
    ];
    final container = createTestContainer(
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
    );

    final available = await container.read(
      roleCandidatesProvider(query()).future,
    );
    final withRole = await container.read(
      roleCandidatesProvider(
        query(filter: RoleCandidatesFilter.withRole),
      ).future,
    );

    expect(available.items.single.userId, 'a');
    expect(withRole.items.single.userId, 'b');
    expect(repo.roleCandidateCalls.map((c) => c.filter), [
      RoleCandidatesFilter.available,
      RoleCandidatesFilter.withRole,
    ]);
  });

  test('detail provider returns the detail', () async {
    final container = createTestContainer(
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
    );
    const detailQuery = RoleCandidateDetailQuery(
      clubId: 1,
      sectionId: 163,
      userId: 'u1',
    );
    repo.roleCandidateDetailResult = Right(
      RoleCandidateDetail(candidate: candidate(id: 'u1'), honorsCount: 4),
    );

    final detail = await container.read(
      roleCandidateDetailProvider(detailQuery).future,
    );

    expect(detail.honorsCount, 4);
    expect(repo.roleCandidateDetailCalls, ['u1']);
  });

  test('detail provider fails with the original Failure', () async {
    final container = createTestContainer(
      overrides: [membersRepositoryProvider.overrideWithValue(repo)],
    );
    const detailQuery = RoleCandidateDetailQuery(
      clubId: 1,
      sectionId: 163,
      userId: 'u1',
    );
    repo.roleCandidateDetailResult =
        const Left(ServerFailure(message: 'x', code: 500));
    container.listen(roleCandidateDetailProvider(detailQuery), (_, __) {});

    await expectLater(
      container.read(roleCandidateDetailProvider(detailQuery).future),
      throwsA(isA<ServerFailure>()),
    );
  });
}
