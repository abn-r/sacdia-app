import '../entities/cache_info.dart';
import '../entities/sync_result.dart';

/// Read + mutate boundary for the app's local cache / last-sync surface.
///
/// Concrete adapters compose filesystem/cache/storage dependencies; tests can
/// supply a fake by overriding the provider at the composition boundary.
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

  /// Stores the timestamp for a successful force-sync.
  ///
  /// Cross-provider invalidation belongs to presentation/composition code, not
  /// to this data repository. This method only persists the result.
  Future<SyncResult> recordSuccessfulSync(DateTime syncedAt);
}
