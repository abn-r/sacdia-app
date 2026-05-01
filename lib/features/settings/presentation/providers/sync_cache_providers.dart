import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/realtime/realtime_ref.dart';
import '../../../../providers/storage_provider.dart';
import '../../data/repositories/cache_repository_impl.dart';
import '../../domain/entities/cache_info.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/repositories/cache_repository.dart';

/// Singleton repository. Kept non-autoDispose — the repo is cheap and we
/// want [cacheInfoProvider] / mutations to share one instance across
/// rebuilds of the Settings screen.
final cacheRepositoryProvider = Provider<CacheRepository>((ref) {
  final storage = ref.watch(localStorageProvider);
  return CacheRepositoryImpl(localStorage: storage);
});

/// Reactive snapshot of the cache footprint + last sync timestamp.
///
/// Invalidate this provider (via `ref.invalidate(cacheInfoProvider)`) to
/// force a re-scan — used after clearing the cache or after a successful
/// force-sync so the UI picks up the new "hace X min" value.
final cacheInfoProvider =
    FutureProvider.autoDispose<CacheInfo>((ref) async {
  final repo = ref.watch(cacheRepositoryProvider);
  return repo.getCacheInfo();
});

// ── Force-sync controller ────────────────────────────────────────────────────

/// State for [syncControllerProvider]. Thin enum + optional result — the UI
/// reads `.inProgress` to gate the button and `.lastResult` for the snackbar.
class SyncControllerState {
  final bool inProgress;
  final SyncResult? lastResult;

  const SyncControllerState({required this.inProgress, required this.lastResult});

  const SyncControllerState.idle()
      : inProgress = false,
        lastResult = null;

  SyncControllerState copyWith({bool? inProgress, SyncResult? lastResult}) {
    return SyncControllerState(
      inProgress: inProgress ?? this.inProgress,
      lastResult: lastResult ?? this.lastResult,
    );
  }
}

class SyncController extends AutoDisposeNotifier<SyncControllerState> {
  @override
  SyncControllerState build() => const SyncControllerState.idle();

  /// Runs a force-sync. Callers pass a [RealtimeRef] wrapping their own
  /// [WidgetRef] so provider invalidations affect the active tree.
  Future<SyncResult> run(RealtimeRef rtRef) async {
    if (state.inProgress) {
      // Guard against double-taps — return the last known result so the
      // caller can still render something if it wants.
      return state.lastResult ?? const SyncResult.error('busy');
    }
    state = state.copyWith(inProgress: true);
    final repo = ref.read(cacheRepositoryProvider);
    final result = await repo.forceSync(rtRef);
    // Refresh the info tile so "Última sincronización" updates.
    ref.invalidate(cacheInfoProvider);
    state = SyncControllerState(inProgress: false, lastResult: result);
    return result;
  }
}

final syncControllerProvider =
    AutoDisposeNotifierProvider<SyncController, SyncControllerState>(
  SyncController.new,
);

// ── Clear-cache controller ───────────────────────────────────────────────────

/// Mode for [ClearCacheController.run] — the UI chooses based on which
/// menu item the user tapped.
enum ClearCacheMode { imagesOnly, allData }

class ClearCacheState {
  final bool inProgress;
  final String? errorMessage;

  const ClearCacheState({required this.inProgress, required this.errorMessage});

  const ClearCacheState.idle()
      : inProgress = false,
        errorMessage = null;
}

class ClearCacheController extends AutoDisposeNotifier<ClearCacheState> {
  @override
  ClearCacheState build() => const ClearCacheState.idle();

  Future<bool> run(ClearCacheMode mode) async {
    if (state.inProgress) return false;
    state = const ClearCacheState(inProgress: true, errorMessage: null);
    try {
      final repo = ref.read(cacheRepositoryProvider);
      if (mode == ClearCacheMode.imagesOnly) {
        await repo.clearImageCaches();
      } else {
        await repo.clearAllData();
      }
      ref.invalidate(cacheInfoProvider);
      state = const ClearCacheState(inProgress: false, errorMessage: null);
      return true;
    } catch (e) {
      state = ClearCacheState(inProgress: false, errorMessage: e.toString());
      return false;
    }
  }
}

final clearCacheControllerProvider =
    AutoDisposeNotifierProvider<ClearCacheController, ClearCacheState>(
  ClearCacheController.new,
);
