import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Keeps the provider that owns this [Ref] alive while [action] runs.
///
/// Widgets often call a notifier method with `ref.read(x.notifier).method()`
/// and never watch `x`. An autoDispose provider then has no listener, so
/// Riverpod 3 disposes it while the method is awaiting, and the next use of
/// `ref` or `state` throws "Cannot use the Ref ... after it has been disposed".
///
/// Wrap every notifier method that touches `ref` or `state` after an `await`:
///
/// ```dart
/// Future<bool> save() => ref.keepAliveDuring(() async {
///   final result = await repository.save();
///   state = AsyncData(result);
///   return true;
/// });
/// ```
///
/// The provider may be disposed once [action] settles, after the caller's
/// `await` resumes, so the caller can still read its final state right away.
extension KeepAliveDuring on Ref {
  Future<T> keepAliveDuring<T>(Future<T> Function() action) async {
    final link = keepAlive();
    try {
      return await action();
    } finally {
      link.close();
    }
  }
}
