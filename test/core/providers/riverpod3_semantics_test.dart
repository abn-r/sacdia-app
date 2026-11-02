// Semántica de Riverpod 3.x de la que depende la app (spec riverpod-3-migration):
//  - S3.1/S3.2: reintento desactivado (helpers de test y raíz de la app).
//  - S4.2: qué tipo de error ve quien lee un provider fallido (`ProviderException`).
//  - S4.3: `AsyncError` conserva el valor previo salvo `unwrapPrevious()`.
//  - S5.3: estado con `==` filtra reconstrucciones iguales, pero `isLoading` se ve.
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/app_provider_retry.dart';

import '../../support/riverpod_test_support.dart';

class _Boom implements Exception {
  @override
  String toString() => '_Boom';
}

/// Valor con igualdad estructural, como `DashboardSummary` o `UserEntity`.
class _Value {
  const _Value(this.label);
  final String label;

  @override
  bool operator ==(Object other) => other is _Value && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// Notifier asíncrono cuyo `build` puede fallar a demanda.
class _Flaky extends AsyncNotifier<int> {
  static bool failNext = false;
  static int builds = 0;

  @override
  Future<int> build() async {
    builds++;
    if (failNext) throw _Boom();
    return 1;
  }
}

final _flakyProvider = AsyncNotifierProvider<_Flaky, int>(_Flaky.new);

/// Notifier asíncrono que siempre devuelve un valor igual al anterior.
class _SameValue extends AsyncNotifier<_Value> {
  @override
  Future<_Value> build() async => const _Value('same');
}

final _sameValueProvider = AsyncNotifierProvider<_SameValue, _Value>(
  _SameValue.new,
);

class _SyncValue extends Notifier<_Value> {
  @override
  _Value build() => const _Value('same');

  void set(_Value value) => state = value;
}

final _syncValueProvider = NotifierProvider<_SyncValue, _Value>(
  _SyncValue.new,
);

void main() {
  setUp(() {
    _Flaky.failNext = false;
    _Flaky.builds = 0;
  });

  group('retry is off (S3.1)', () {
    testWidgets('a failing provider settles to AsyncError with no timers',
        (tester) async {
      var builds = 0;
      final failing = FutureProvider<int>((ref) async {
        builds++;
        throw _Boom();
      });

      await tester.pumpWidget(
        testProviderScope(
          child: Consumer(
            builder: (context, ref, _) => Text(
              ref.watch(failing).hasError ? 'error' : 'loading',
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );
      expect(find.text('loading'), findsOneWidget);

      await tester.pump();
      expect(find.text('error'), findsOneWidget);

      // Con el reintento por defecto de Riverpod 3 (200 ms exponencial) el
      // provider volvería a `AsyncLoading` y reconstruiría; el temporizador
      // pendiente además haría fallar el test al terminar.
      await tester.pump(const Duration(minutes: 1));
      expect(find.text('error'), findsOneWidget);
      expect(builds, 1);
    });

    test('a container made by the helper surfaces AsyncError immediately',
        () async {
      final container = createTestContainer();

      await expectLater(
        container.read(_flakyProvider.future),
        completion(1),
      );
      _Flaky.failNext = true;
      container.invalidate(_flakyProvider);
      await expectLater(
        container.read(_flakyProvider.future),
        throwsA(isA<_Boom>()),
      );

      expect(container.read(_flakyProvider).hasError, isTrue);
      expect(_Flaky.builds, 2);
    });
  });

  group('app retry policy (S3.2)', () {
    test('appProviderRetry never retries, whatever the error', () {
      expect(appProviderRetry(0, _Boom()), isNull);
      expect(appProviderRetry(3, Exception('network')), isNull);
      expect(appProviderRetry(0, StateError('x')), isNull);
    });

    test('a container using the app policy settles to AsyncError once',
        () async {
      // Contenedor crudo a propósito: aquí se prueba la política de producción,
      // no la de los helpers de test.
      final container = ProviderContainer(retry: appProviderRetry);
      addTearDown(container.dispose);
      _Flaky.failNext = true;

      await expectLater(
        container.read(_flakyProvider.future),
        throwsA(isA<_Boom>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(container.read(_flakyProvider).hasError, isTrue);
      expect(_Flaky.builds, 1, reason: 'no retry after 200/400 ms');
    });

    test('lib/main.dart wires the single root ProviderScope to it', () {
      final source = File('lib/main.dart').readAsStringSync();

      expect('ProviderScope('.allMatches(source), hasLength(1));
      expect(source, contains('retry: appProviderRetry'));
      expect(source, isNot(contains('retry: (_, __)')));
    });
  });

  group('failed providers and ProviderException (S4.2)', () {
    test('reading .future surfaces the original error type', () async {
      final container = createTestContainer();
      _Flaky.failNext = true;

      await expectLater(
        container.read(_flakyProvider.future),
        throwsA(isA<_Boom>()),
      );
    });

    test('a failed AsyncError has no value, and requireValue wraps the error',
        () async {
      final container = createTestContainer();
      _Flaky.failNext = true;
      await container.read(_flakyProvider.future).then((_) {}, onError: (_) {});

      final state = container.read(_flakyProvider);
      expect(state.hasError, isTrue);
      // 2.6 relanzaba aquí; en 3.x `.value` es null sin valor previo.
      expect(state.value, isNull);
      expect(
        () => state.requireValue,
        throwsA(
          isA<ProviderException>()
              .having((e) => e.exception, 'exception', isA<_Boom>()),
        ),
      );
    });

    test('a sync read of a failing provider throws ProviderException', () {
      final failing = Provider<int>((ref) => throw _Boom());
      final container = createTestContainer();

      expect(
        () => container.read(failing),
        throwsA(
          isA<ProviderException>()
              .having((e) => e.exception, 'exception', isA<_Boom>()),
        ),
      );
    });

    test('a dependent of a failing provider wraps one level deeper', () {
      final failing = Provider<int>((ref) => throw _Boom());
      final dependent = Provider<int>((ref) => ref.watch(failing) + 1);
      final container = createTestContainer();

      Object? thrown;
      try {
        container.read(dependent);
      } catch (e) {
        thrown = e;
      }

      expect(thrown, isA<ProviderException>());
      final inner = (thrown! as ProviderException).exception;
      expect(inner, isA<ProviderException>());
      expect((inner as ProviderException).exception, isA<_Boom>());
    });
  });

  group('AsyncError keeps the previous value (S4.3)', () {
    test('.value returns the stale value, unwrapPrevious() drops it', () async {
      final container = createTestContainer();
      expect(await container.read(_flakyProvider.future), 1);

      _Flaky.failNext = true;
      container.invalidate(_flakyProvider);
      await container.read(_flakyProvider.future).then((_) {}, onError: (_) {});

      final failed = container.read(_flakyProvider);
      expect(failed.hasError, isTrue);
      expect(failed.value, 1, reason: 'previous data survives the failure');
      expect(failed.hasValue, isTrue);

      final clean = failed.unwrapPrevious();
      expect(clean.hasError, isTrue);
      expect(clean.value, isNull);
      expect(clean.hasValue, isFalse);
    });
  });

  group('== filtering keeps loading observable (S5.3)', () {
    test('an equal re-fetch still passes through loading, with previous value',
        () async {
      final container = createTestContainer();
      final seen = <AsyncValue<_Value>>[];
      container.listen(_sameValueProvider, (_, next) => seen.add(next));
      await container.read(_sameValueProvider.future);
      seen.clear();

      container.invalidate(_sameValueProvider);
      final refreshed = await container.read(_sameValueProvider.future);

      expect(refreshed, const _Value('same'));
      expect(seen.first.isLoading, isTrue);
      // invalidate/refresh = refreshing (reloading es `state = AsyncLoading()`).
      expect(seen.first.isRefreshing, isTrue);
      expect(seen.first.value, const _Value('same'));
      expect(seen.last.isLoading, isFalse);
      expect(seen.last.value, const _Value('same'));
    });

    test('a sync state set to an equal value does not notify', () {
      final container = createTestContainer();
      var notifications = 0;
      container.listen(_syncValueProvider, (_, __) => notifications++);

      container.read(_syncValueProvider.notifier).set(const _Value('same'));
      expect(notifications, 0);

      container.read(_syncValueProvider.notifier).set(const _Value('other'));
      expect(notifications, 1);
    });
  });
}
