import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/keep_alive_during.dart';

import '../../support/riverpod_test_support.dart';

class _Counter extends Notifier<int> {
  @override
  int build() => 0;

  Future<int> slowIncrement({bool keepAlive = true}) {
    Future<int> body() async {
      await Future<void>.delayed(const Duration(milliseconds: 10));
      state = state + 1;
      return state;
    }

    return keepAlive ? ref.keepAliveDuring(body) : body();
  }

  Future<void> slowFail() => ref.keepAliveDuring(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw StateError('boom');
      });
}

final _counterProvider = NotifierProvider.autoDispose<_Counter, int>(
  _Counter.new,
);

void main() {
  // Pins the Riverpod 3 behavior keepAliveDuring exists for: without it, an
  // autoDispose notifier nobody listens to is disposed mid-await and the next
  // `state` write throws.
  test('without keepAliveDuring the unlistened notifier throws', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(_counterProvider.notifier).slowIncrement(keepAlive: false),
      throwsA(predicate(
        (e) => e.toString().contains('after it has been disposed'),
      )),
    );
  });

  test('keepAliveDuring lets the method finish and keeps its state readable',
      () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    final value =
        await container.read(_counterProvider.notifier).slowIncrement();

    expect(value, 1);
    expect(container.read(_counterProvider), 1);
  });

  test('keepAliveDuring releases the provider after the action settles',
      () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    await container.read(_counterProvider.notifier).slowIncrement();
    await container.pump();

    // Disposed once released: a fresh read rebuilds from 0.
    expect(container.read(_counterProvider), 0);
  });

  test('keepAliveDuring rethrows and still releases on failure', () async {
    final container = createTestContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(_counterProvider.notifier).slowFail(),
      throwsA(isA<StateError>()),
    );
    await container.pump();
    expect(container.read(_counterProvider), 0);
  });
}
