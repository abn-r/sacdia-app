/// Tests for the paginated pending-evidence queue.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/domain/entities/evidence_review_item.dart';
import 'package:sacdia_app/features/coordinator/presentation/providers/coordinator_providers.dart';

import '../../coordinator_test_harness.dart';

EvidenceReviewItem _item(int i) => EvidenceReviewItem(
      id: '$i',
      type: EvidenceReviewType.classType,
      status: EvidenceReviewStatus.pending,
      memberName: 'M $i',
      submittedAt: DateTime(2026, 1, 1).add(Duration(hours: i)),
      fileCount: 1,
    );

final _all = [for (var i = 0; i < 45; i++) _item(i)];

ProviderContainer _container(PendingPageLoader loader) {
  final container = ProviderContainer(
    overrides: [pendingEvidenceOverride(loader)],
  );
  addTearDown(container.dispose);
  // Keep the autoDispose family alive between reads.
  container.listen(pendingEvidenceProvider(null), (_, __) {});
  return container;
}

PendingEvidenceNotifier _notifier(ProviderContainer c) =>
    c.read(pendingEvidenceProvider(null).notifier);

Future<PendingEvidenceState> _queue(ProviderContainer c) =>
    c.read(pendingEvidenceProvider(null).future);

void main() {
  test('build loads the first page with the server total', () async {
    final pages = <int>[];
    final c = _container((type, page) {
      pages.add(page);
      return pageOf(_all, page);
    });

    final queue = await _queue(c);

    expect(pages, [1]);
    expect(queue.items, hasLength(20));
    expect(queue.total, 45);
    expect(queue.hasMore, isTrue);
  });

  test('loadMore appends pages until the total is reached', () async {
    final pages = <int>[];
    final c = _container((type, page) {
      pages.add(page);
      return pageOf(_all, page);
    });
    await _queue(c);

    await _notifier(c).loadMore();
    await _notifier(c).loadMore();
    final queue = c.read(pendingEvidenceProvider(null)).requireValue;

    expect(pages, [1, 2, 3]);
    expect(queue.items.map((i) => i.id), [for (var i = 0; i < 45; i++) '$i']);
    expect(queue.hasMore, isFalse);

    // Nothing left: no more requests.
    await _notifier(c).loadMore();
    expect(pages, [1, 2, 3]);
  });

  test('concurrent loadMore calls request the next page once', () async {
    final pages = <int>[];
    final c = _container((type, page) async {
      pages.add(page);
      return pageOf(_all, page);
    });
    await _queue(c);

    await Future.wait([_notifier(c).loadMore(), _notifier(c).loadMore()]);

    expect(pages, [1, 2]);
  });

  test('does not duplicate items that shifted between pages', () async {
    final c = _container(
      (type, page) => EvidenceReviewPage(
        // Page 2 repeats item 19 (the queue moved by one).
        items: page == 1 ? _all.sublist(0, 20) : _all.sublist(19, 39),
        total: 45,
        page: page,
        limit: kPendingEvidencePageSize,
      ),
    );
    await _queue(c);

    await _notifier(c).loadMore();
    final ids = c.read(pendingEvidenceProvider(null)).requireValue.items;

    expect(ids, hasLength(39));
    expect(ids.map((i) => i.id).toSet(), hasLength(39));
  });

  test('an empty page ends the queue even if the total is stale', () async {
    final pages = <int>[];
    final c = _container((type, page) {
      pages.add(page);
      return EvidenceReviewPage(
        items: page == 1 ? _all.sublist(0, 20) : const [],
        total: 45,
        page: page,
        limit: kPendingEvidencePageSize,
      );
    });
    await _queue(c);

    await _notifier(c).loadMore();
    await _notifier(c).loadMore();

    expect(pages, [1, 2]);
    expect(c.read(pendingEvidenceProvider(null)).requireValue.hasMore, isFalse);
  });

  test('a failed page keeps the loaded items and can be retried', () async {
    var fail = true;
    final c = _container((type, page) {
      if (page == 2 && fail) throw Exception('boom');
      return pageOf(_all, page);
    });
    await _queue(c);

    await _notifier(c).loadMore();
    var queue = c.read(pendingEvidenceProvider(null)).requireValue;
    expect(queue.items, hasLength(20));
    expect(queue.loadMoreFailed, isTrue);
    expect(queue.hasMore, isTrue);

    fail = false;
    await _notifier(c).loadMore();
    queue = c.read(pendingEvidenceProvider(null)).requireValue;
    expect(queue.items, hasLength(40));
    expect(queue.loadMoreFailed, isFalse);
  });

  test('invalidating restarts from page 1 and drops a late page', () async {
    final second = Completer<EvidenceReviewPage>();
    final pages = <int>[];
    final c = _container((type, page) {
      pages.add(page);
      return page == 1 ? pageOf(_all, 1) : second.future;
    });
    await _queue(c);

    final pending = _notifier(c).loadMore();
    c.invalidate(pendingEvidenceProvider);
    await _queue(c);

    second.complete(pageOf(_all, 2));
    await pending;

    final queue = c.read(pendingEvidenceProvider(null)).requireValue;
    expect(pages, [1, 2, 1]);
    expect(queue.items, hasLength(20));
    expect(queue.page, 1);
    expect(queue.isLoadingMore, isFalse);
  });

  group('EvidenceReviewPage.hasMore', () {
    EvidenceReviewPage page(int count, {int? total, int page = 1}) =>
        EvidenceReviewPage(
          items: [for (var i = 0; i < count; i++) _item(i)],
          total: total,
          page: page,
          limit: 20,
        );

    test('uses the server total when present', () {
      expect(page(20, total: 45).hasMore, isTrue);
      expect(page(20, total: 40, page: 2).hasMore, isFalse);
      expect(page(5, total: 5).hasMore, isFalse);
    });

    test('without a total, only a full page may have more', () {
      expect(page(20).hasMore, isTrue);
      expect(page(19).hasMore, isFalse);
    });
  });
}
