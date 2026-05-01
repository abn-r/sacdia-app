import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thin read/invalidate adapter used by the realtime invalidation subsystem.
///
/// Both [Ref] (from a Riverpod [Provider]) and [WidgetRef] (from a
/// [ConsumerWidget] / [ConsumerStatefulWidget]) expose [read] and [invalidate],
/// but they are distinct types in Riverpod 2.x.
///
/// [RealtimeRef] bridges the gap: wrap either with [RealtimeRef.fromRef] or
/// [RealtimeRef.fromWidgetRef] and pass the result to
/// [RealtimeResourceRegistry.invalidate] / [RealtimeInvalidationHandler].
abstract class RealtimeRef {
  /// Reads the current value of [provider].
  T read<T>(ProviderListenable<T> provider);

  /// Schedules a rebuild/refetch of [provider].
  void invalidate(ProviderOrFamily provider);

  // ── Factories ──────────────────────────────────────────────────────────────

  /// Wraps a Riverpod [Ref] (available inside [Provider], [AsyncNotifier], etc.)
  static RealtimeRef fromRef(Ref ref) => _RefAdapter(ref);

  /// Wraps a [WidgetRef] (available inside [ConsumerWidget.build] and
  /// [ConsumerState] methods).
  static RealtimeRef fromWidgetRef(WidgetRef widgetRef) =>
      _WidgetRefAdapter(widgetRef);
}

// ─────────────────────────────────────────────────────────────────────────────

class _RefAdapter implements RealtimeRef {
  const _RefAdapter(this._ref);
  final Ref _ref;

  @override
  T read<T>(ProviderListenable<T> provider) => _ref.read(provider);

  @override
  void invalidate(ProviderOrFamily provider) => _ref.invalidate(provider);
}

class _WidgetRefAdapter implements RealtimeRef {
  const _WidgetRefAdapter(this._widgetRef);
  final WidgetRef _widgetRef;

  @override
  T read<T>(ProviderListenable<T> provider) => _widgetRef.read(provider);

  @override
  void invalidate(ProviderOrFamily provider) => _widgetRef.invalidate(provider);
}
