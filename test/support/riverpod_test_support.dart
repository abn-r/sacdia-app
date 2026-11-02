/// Single construction point for Riverpod containers and scopes in tests.
///
/// Every test builds its `ProviderContainer` / `ProviderScope` through these
/// helpers so that container-level options (notably `retry`) can be changed in
/// one place. Both pass `retry: noRetry` (Riverpod 3 retries failing providers
/// by default), and nowhere else in `test/` builds a raw container or scope.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';

/// Builds a [ProviderContainer] and registers `addTearDown(container.dispose)`.
///
/// Must be called from inside a test body, `setUp`, or any other context where
/// `addTearDown` is valid (not `setUpAll` or top-level initializers).
ProviderContainer createTestContainer({
  List<Override> overrides = const [],
  ProviderContainer? parent,
  List<ProviderObserver>? observers,
}) {
  final container = ProviderContainer(
    parent: parent,
    overrides: overrides,
    observers: observers,
    retry: noRetry,
  );
  addTearDown(container.dispose);
  return container;
}

/// Widget-level counterpart of [createTestContainer].
ProviderScope testProviderScope({
  List<Override> overrides = const [],
  List<ProviderObserver>? observers,
  required Widget child,
}) {
  return ProviderScope(
    overrides: overrides,
    observers: observers,
    retry: noRetry,
    child: child,
  );
}

/// Retry policy that never retries a failed provider.
///
/// Riverpod 3.x retries failing providers by default (up to 10 times with
/// exponential backoff), which leaves tests with pending timers and
/// `AsyncLoading` instead of `AsyncError`. Passed as `retry: noRetry` inside
/// [createTestContainer] and [testProviderScope].
Duration? noRetry(int retryCount, Object error) => null;
