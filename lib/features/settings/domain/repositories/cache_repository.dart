import '../../../../core/realtime/realtime_ref.dart';
import '../entities/cache_info.dart';
import '../entities/sync_result.dart';

/// Read + mutate boundary for the app's local cache / last-sync surface.
///
/// The implementation lives in
/// `features/settings/data/repositories/cache_repository_impl.dart` and
/// composes `path_provider`, `SacCacheManager`, `DefaultCacheManager` and
/// `LocalStorage` — tests can supply a fake by overriding the provider.
abstract class CacheRepository {
  /// Computes the current cache footprint + reads the last-sync timestamp.
  ///
  /// Disk work runs in a background isolate (via `compute`) with a soft
  /// 5s timeout; on timeout the temp-directory bytes fall back to 0 so
  /// the UI never blocks on a cold filesystem.
  Future<CacheInfo> getCacheInfo();

  /// Clears only image-related caches: [SacCacheManager] +
  /// [DefaultCacheManager] + `PaintingBinding.imageCache`.
  ///
  /// Safe to call without confirmation — no user data is touched.
  Future<void> clearImageCaches();

  /// Clears everything in [clearImageCaches] PLUS:
  ///   - the recursive contents of `getTemporaryDirectory()`
  ///   - non-whitelisted SharedPreferences keys
  ///
  /// NEVER touches `flutter_secure_storage` (auth tokens, biometric keys).
  ///
  /// The whitelist preserved in SharedPreferences (prefix match):
  ///   `theme_`, `locale_`, `notification_`, `auth_`, `fcm_`,
  ///   `accessibility_`, `biometric_`, plus `EasyLocalization.Locale` and
  ///   the `last_global_sync_at` key (kept so the UI does not regress to
  ///   "never synced" right after a clear).
  Future<void> clearAllData();

  /// Fires the cross-resource invalidation chain + updates the
  /// `last_global_sync_at` SharedPreferences key on success.
  ///
  /// Callers pass a [RealtimeRef] (usually via
  /// `RealtimeRef.fromWidgetRef(ref)` from a Riverpod consumer) so the
  /// repository can drive provider invalidations without reaching into
  /// Flutter/Riverpod internals itself.
  Future<SyncResult> forceSync(RealtimeRef ref);
}
