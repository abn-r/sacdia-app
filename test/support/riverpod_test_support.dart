// ignore_for_file: unnecessary_import
/// Single construction point for Riverpod containers and scopes in tests.
///
/// Every test builds its `ProviderContainer` / `ProviderScope` through these
/// helpers so that container-level options (notably `retry`) can be changed in
/// one place. Under Riverpod 2.6 neither constructor has a `retry` parameter,
/// so [noRetry] is defined but unused. The 3.x bump adds `retry: noRetry` in
/// the two helper bodies below and nowhere else.
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
    child: child,
  );
}

/// Retry policy that never retries a failed provider.
///
/// Riverpod 3.x retries failing providers by default (up to 10 times with
/// exponential backoff), which leaves tests with pending timers and
/// `AsyncLoading` instead of `AsyncError`. Unused under Riverpod 2.6; the 3.x
/// bump passes it as `retry: noRetry` inside [createTestContainer] and
/// [testProviderScope].
Duration? noRetry(int retryCount, Object error) => null;
