import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/consent_pending_queue.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/consent_review_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';

import '../../coordinator_test_support.dart';

Map<String, Object?> _item(String id, int sectionId, {String name = 'Ana'}) =>
    pendingItemJson(id: id, sectionId: sectionId, name: name);

String _assignment(String id, int sectionId) =>
    '$sectionId/membership-requests/$id';

void main() {
  late FakeCoordinatorRepository repo;

  setUp(() => repo = FakeCoordinatorRepository());

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [coordinatorRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    return c;
  }

  Right<Failure, ConsentPendingPage> page({
    required List<Map<String, Object?>> items,
    int? total,
    int offset = 0,
    List<Map<String, Object?>> bySection = const [],
  }) =>
      Right(
        pendingPage(
          items: items,
          total: total,
          offset: offset,
          bySection: bySection,
        ),
      );

  group('first load', () {
    test('is ONE call to the aggregate endpoint, no per-section fan-out',
        () async {
      repo.results = [
        page(items: [_item('a', 1), _item('b', 2)], total: 2),
      ];
      final c = container();

      final state = await c.read(consentReviewProvider.future);

      expect(repo.calls, [(limit: ConsentReviewNotifier.pageSize, offset: 0)]);
      expect(state.access, ConsentQueueAccess.granted);
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('a', 1), _assignment('b', 2)]);
      expect(state.total, 2);
      expect(state.hasMore, isFalse);
    });

    test('the page size is the documented default of the endpoint', () {
      expect(ConsentReviewNotifier.pageSize, 50);
    });

    test('keeps the per-section counts for the summary', () async {
      repo.results = [
        page(
          items: [_item('a', 1)],
          total: 3,
          bySection: [
            pendingSectionJson(sectionId: 1, count: 2),
            pendingSectionJson(sectionId: 5, count: 1),
          ],
        ),
      ];

      final state = await container().read(consentReviewProvider.future);

      expect(
          state.bySection.map((s) => (s.clubSectionId, s.pendingConsentCount)),
          [(1, 2), (5, 1)]);
    });

    test('an empty queue is granted access with nothing to show', () async {
      repo.results = [page(items: const [])];

      final state = await container().read(consentReviewProvider.future);

      expect(state.access, ConsentQueueAccess.granted);
      expect(state.items, isEmpty);
      expect(state.total, 0);
      expect(state.hasMore, isFalse);
    });
  });

  group('pagination', () {
    test('has more while fewer items are loaded than the total', () async {
      repo.results = [
        page(items: [_item('a', 1), _item('b', 1)], total: 5),
      ];

      final state = await container().read(consentReviewProvider.future);

      expect(state.hasMore, isTrue);
      expect(state.total, 5);
    });

    test('loadMore asks for the next offset and appends in order', () async {
      repo.results = [
        page(items: [_item('a', 1), _item('b', 1)], total: 3),
        page(items: [_item('c', 2)], total: 3, offset: 2),
      ];
      final c = container();
      await c.read(consentReviewProvider.future);

      await c.read(consentReviewProvider.notifier).loadMore();

      expect(
          repo.calls.last, (limit: ConsentReviewNotifier.pageSize, offset: 2));
      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId), [
        _assignment('a', 1),
        _assignment('b', 1),
        _assignment('c', 2),
      ]);
      expect(state.hasMore, isFalse);
      expect(state.loadingMore, isFalse);
    });

    test('loadMore never duplicates an item that is already listed', () async {
      repo.results = [
        page(items: [_item('a', 1), _item('b', 1)], total: 4),
        page(items: [_item('b', 1), _item('c', 1)], total: 3, offset: 2),
      ];
      final c = container();
      await c.read(consentReviewProvider.future);

      await c.read(consentReviewProvider.notifier).loadMore();

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('a', 1), _assignment('b', 1), _assignment('c', 1)]);
      // The server is the authority for the total.
      expect(state.total, 3);
    });

    test('loadMore with nothing left does not call the server', () async {
      repo.results = [
        page(items: [_item('a', 1)])
      ];
      final c = container();
      await c.read(consentReviewProvider.future);

      await c.read(consentReviewProvider.notifier).loadMore();

      expect(repo.calls, hasLength(1));
    });

    test('a second loadMore while one is in flight is ignored', () async {
      repo.results = [
        page(items: [_item('a', 1)], total: 3),
        page(items: [_item('b', 1)], total: 3, offset: 1),
      ];
      final c = container();
      await c.read(consentReviewProvider.future);
      // Keep the autoDispose notifier alive while the test awaits events.
      c.listen(consentReviewProvider, (_, __) {});
      repo.gate = Completer<void>();
      final notifier = c.read(consentReviewProvider.notifier);

      final first = notifier.loadMore();
      await pumpEventQueue();
      expect(c.read(consentReviewProvider).requireValue.loadingMore, isTrue);
      await notifier.loadMore();
      repo.gate!.complete();
      await first;

      expect(repo.calls, hasLength(2));
    });

    test('a failed loadMore keeps the loaded items and can be retried',
        () async {
      repo.results = [
        page(items: [_item('a', 1)], total: 2),
        const Left(ServerFailure(message: 'x', code: 500)),
        page(items: [_item('b', 1)], total: 2, offset: 1),
      ];
      final c = container();
      await c.read(consentReviewProvider.future);
      final notifier = c.read(consentReviewProvider.notifier);

      await notifier.loadMore();
      var state = c.read(consentReviewProvider).requireValue;
      expect(state.items, hasLength(1));
      expect(state.loadMoreFailed, isTrue);
      expect(state.loadingMore, isFalse);
      expect(state.hasMore, isTrue);

      await notifier.loadMore();
      state = c.read(consentReviewProvider).requireValue;
      expect(state.items, hasLength(2));
      expect(state.loadMoreFailed, isFalse);
    });
  });

  group('access', () {
    test('403 GUARD_CLUB_SCOPE_REQUIRED means no assigned sections', () async {
      repo.results = [const Left(noSectionsFailure)];

      final state = await container().read(consentReviewProvider.future);

      expect(state.access, ConsentQueueAccess.noSections);
      expect(state.items, isEmpty);
      expect(state.hasMore, isFalse);
    });

    test('403 GUARD_PERMISSION_DENIED means the queue is not for this user',
        () async {
      repo.results = [const Left(permissionDeniedFailure)];

      final state = await container().read(consentReviewProvider.future);

      expect(state.access, ConsentQueueAccess.denied);
      expect(state.items, isEmpty);
    });

    for (final code in ['ACTING_FOR_SCOPE_DENIED', 'PRINCIPAL_SCOPE_DENIED']) {
      test('403 $code is also denied', () async {
        repo.results = [
          Left(AuthFailure(message: 'x', code: 403, errorCode: code)),
        ];

        final state = await container().read(consentReviewProvider.future);

        expect(state.access, ConsentQueueAccess.denied);
      });
    }

    test('decides by the error code, never by the message', () async {
      repo.results = [
        const Left(
          AuthFailure(
            message: 'GUARD_CLUB_SCOPE_REQUIRED',
            code: 403,
            errorCode: 'SOMETHING_ELSE',
          ),
        ),
      ];

      await expectLater(
        container().read(consentReviewProvider.future),
        throwsA(isA<Failure>()),
      );
    });

    test('any other failure is an error to retry, not an empty queue',
        () async {
      repo.results = [const Left(ServerFailure(message: 'x', code: 500))];

      await expectLater(
        container().read(consentReviewProvider.future),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('refresh after invalidate', () {
    test('a refresh uses a fresh token and loads (the old one is cancelled)',
        () async {
      repo.results = [
        page(items: [_item('a', 1)], total: 1),
        page(items: [_item('a', 1), _item('b', 1)], total: 2),
      ];
      final c = container();
      c.listen(consentReviewProvider, (_, __) {});
      await c.read(consentReviewProvider.future);

      c.invalidate(consentReviewProvider);
      final state = await c.read(consentReviewProvider.future);

      // The fake FAILS when handed a cancelled token: this is data, not error.
      expect(state.items, hasLength(2));
      final first = repo.cancelTokens[0] as CancelToken;
      final second = repo.cancelTokens[1] as CancelToken;
      expect(identical(first, second), isFalse);
      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isFalse);
    });

    test('survives several refreshes in a row', () async {
      repo.results = [page(items: [_item('a', 1)], total: 1)];
      final c = container();
      c.listen(consentReviewProvider, (_, __) {});
      await c.read(consentReviewProvider.future);

      for (var i = 0; i < 3; i++) {
        c.invalidate(consentReviewProvider);
        await c.read(consentReviewProvider.future);
      }

      expect(c.read(consentReviewProvider).hasError, isFalse);
      expect(repo.calls, hasLength(4));
    });

    test('loadMore still writes after a refresh', () async {
      repo.results = [
        page(items: [_item('a', 1)], total: 2),
        page(items: [_item('a', 1)], total: 2),
        page(items: [_item('b', 1)], total: 2, offset: 1),
      ];
      final c = container();
      c.listen(consentReviewProvider, (_, __) {});
      await c.read(consentReviewProvider.future);
      c.invalidate(consentReviewProvider);
      await c.read(consentReviewProvider.future);

      await c.read(consentReviewProvider.notifier).loadMore();

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('a', 1), _assignment('b', 1)]);
      expect(state.loadMoreFailed, isFalse);
    });

    test('a page that was in flight before the refresh is dropped', () async {
      repo.results = [
        page(items: [_item('a', 1)], total: 2),
        page(items: [_item('z', 1)], total: 2, offset: 1),
        page(items: [_item('x', 1)], total: 1),
      ];
      final c = container();
      c.listen(consentReviewProvider, (_, __) {});
      await c.read(consentReviewProvider.future);
      final notifier = c.read(consentReviewProvider.notifier);

      final gate = repo.gate = Completer<void>();
      final stale = notifier.loadMore();
      await pumpEventQueue();
      // The refresh runs while the old page is still pending.
      c.invalidate(consentReviewProvider);
      gate.complete();
      repo.gate = null;
      await stale;
      await c.read(consentReviewProvider.future);

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('x', 1)]);
    });
  });

  group('loadMore vs removeRequest', () {
    test('does not resurrect a form verified while the page was in flight',
        () async {
      repo.results = [
        page(items: [_item('a', 1), _item('b', 1)], total: 4),
        // The page was already on its way: it still lists the verified 'a'.
        page(items: [_item('a', 1), _item('c', 1)], total: 4, offset: 2),
      ];
      final c = container();
      c.listen(consentReviewProvider, (_, __) {});
      await c.read(consentReviewProvider.future);
      final notifier = c.read(consentReviewProvider.notifier);

      final gate = repo.gate = Completer<void>();
      final pending = notifier.loadMore();
      await pumpEventQueue();
      notifier.removeRequest(_assignment('a', 1));
      gate.complete();
      await pending;

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('b', 1), _assignment('c', 1)]);
      expect(state.loadingMore, isFalse);
    });

    test('a failed page keeps what was removed meanwhile removed', () async {
      repo.results = [
        page(items: [_item('a', 1), _item('b', 1)], total: 4),
        const Left(ServerFailure(message: 'x', code: 500)),
      ];
      final c = container();
      c.listen(consentReviewProvider, (_, __) {});
      await c.read(consentReviewProvider.future);
      final notifier = c.read(consentReviewProvider.notifier);

      final gate = repo.gate = Completer<void>();
      final pending = notifier.loadMore();
      await pumpEventQueue();
      notifier.removeRequest(_assignment('a', 1));
      gate.complete();
      await pending;

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('b', 1)]);
      expect(state.loadMoreFailed, isTrue);
    });

    test('an empty page closes the list instead of leaving a dead "more"',
        () async {
      repo.results = [
        page(items: const [], total: 3),
        page(items: const [], total: 3),
      ];
      final c = container();
      c.listen(consentReviewProvider, (_, __) {});
      await c.read(consentReviewProvider.future);

      await c.read(consentReviewProvider.notifier).loadMore();

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.hasMore, isFalse);
      expect(state.total, 0);
    });
  });

  group('removeRequest', () {
    ProviderContainer loaded() {
      repo.results = [
        page(
          items: [_item('a', 1), _item('b', 1), _item('c', 2)],
          total: 7,
          bySection: [
            pendingSectionJson(sectionId: 1, count: 4),
            pendingSectionJson(sectionId: 2, count: 1),
            pendingSectionJson(sectionId: 3, count: 2),
          ],
        ),
      ];
      return container();
    }

    test('drops the item and decrements the total and its section', () async {
      final c = loaded();
      await c.read(consentReviewProvider.future);

      c.read(consentReviewProvider.notifier).removeRequest(_assignment('a', 1));

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('b', 1), _assignment('c', 2)]);
      expect(state.total, 6);
      expect(
        state.bySection
            .firstWhere((s) => s.clubSectionId == 1)
            .pendingConsentCount,
        3,
      );
    });

    test('a section that reaches zero leaves the summary', () async {
      final c = loaded();
      await c.read(consentReviewProvider.future);

      c.read(consentReviewProvider.notifier).removeRequest(_assignment('c', 2));

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.bySection.map((s) => s.clubSectionId), [1, 3]);
      expect(state.total, 6);
    });

    test('the next page starts after the items that are still listed',
        () async {
      final c = loaded();
      await c.read(consentReviewProvider.future);
      final notifier = c.read(consentReviewProvider.notifier);
      notifier.removeRequest(_assignment('a', 1));
      repo.results = [
        page(items: [_item('d', 3)], total: 6, offset: 2)
      ];
      repo.calls.clear();

      await notifier.loadMore();

      // A verified form left the server queue too: offset = what is listed.
      expect(repo.calls.single.offset, 2);
    });

    test('also drops every other form of the same minor', () async {
      repo.results = [
        page(
          items: [
            pendingItemJson(id: 'a', sectionId: 1, userId: 'minor'),
            pendingItemJson(id: 'b', sectionId: 2, userId: 'other'),
            pendingItemJson(id: 'c', sectionId: 2, userId: 'minor'),
            pendingItemJson(id: 'd', sectionId: 1, userId: 'minor'),
          ],
          total: 6,
          bySection: [
            pendingSectionJson(sectionId: 1, count: 3),
            pendingSectionJson(sectionId: 2, count: 2),
            pendingSectionJson(sectionId: 3, count: 1),
          ],
        ),
      ];
      final c = container();
      await c.read(consentReviewProvider.future);

      c.read(consentReviewProvider.notifier).removeRequest(_assignment('c', 2));

      final state = c.read(consentReviewProvider).requireValue;
      expect(state.items.map((i) => i.request.assignmentId),
          [_assignment('b', 2)]);
      expect(state.total, 3);
      expect(
        state.bySection.map((s) => (s.clubSectionId, s.pendingConsentCount)),
        [(1, 1), (2, 1), (3, 1)],
      );
    });

    test('an unknown id changes nothing', () async {
      final c = loaded();
      final before = await c.read(consentReviewProvider.future);

      c.read(consentReviewProvider.notifier).removeRequest('9/x/nope');

      expect(c.read(consentReviewProvider).requireValue, before);
    });

    test('never takes the total below zero', () async {
      repo.results = [
        page(items: [_item('a', 1)], total: 0)
      ];
      final c = container();
      await c.read(consentReviewProvider.future);

      c.read(consentReviewProvider.notifier).removeRequest(_assignment('a', 1));

      expect(c.read(consentReviewProvider).requireValue.total, 0);
    });
  });

  group('pending count (hub badge)', () {
    test('is one cheap call: limit 1, the total of the queue', () async {
      repo.results = [
        page(items: [_item('a', 1)], total: 42)
      ];
      final c = container();

      final count = await c.read(consentPendingCountProvider.future);

      expect(count, 42);
      expect(repo.calls, [(limit: 1, offset: 0)]);
    });

    test('is null (no badge) when the queue cannot be read', () async {
      repo.results = [const Left(permissionDeniedFailure)];

      expect(
          await container().read(consentPendingCountProvider.future), isNull);
    });
  });
}
