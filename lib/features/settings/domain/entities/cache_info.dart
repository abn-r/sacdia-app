import 'package:flutter/foundation.dart';

/// Snapshot of the app's local cache footprint at a point in time.
///
/// Produced by [CacheRepository.getCacheInfo]. All byte fields are
/// rolled up into [totalBytes] so the UI does not have to sum them.
///
/// [lastSyncAt] reflects the last successful global sync (see
/// `RealtimeResourceRegistry.invalidateAll` + the `last_global_sync_at`
/// SharedPreferences key). May be null if the user has never triggered
/// a force-sync on this device.
@immutable
class CacheInfo {
  /// Total bytes across all app-managed caches (image cache + temp + memory).
  final int totalBytes;

  /// Subset of [totalBytes]: disk bytes held by [SacCacheManager] +
  /// [DefaultCacheManager] (the CachedNetworkImage disk caches).
  final int imagesBytes;

  /// Subset of [totalBytes]: size of the recursive scan of
  /// `getTemporaryDirectory()`. Excluded from [imagesBytes] to avoid
  /// double-counting (the cache managers live inside this directory).
  final int temporaryBytes;

  /// In-memory decoded image cache footprint
  /// (`PaintingBinding.imageCache.currentSizeBytes`). Not persisted — this
  /// resets each app launch.
  final int inMemoryBytes;

  /// UTC timestamp of the last successful force-sync, or null if never.
  final DateTime? lastSyncAt;

  const CacheInfo({
    required this.totalBytes,
    required this.imagesBytes,
    required this.temporaryBytes,
    required this.inMemoryBytes,
    required this.lastSyncAt,
  });

  /// Empty snapshot — useful as the initial state before the first scan
  /// completes.
  static const CacheInfo empty = CacheInfo(
    totalBytes: 0,
    imagesBytes: 0,
    temporaryBytes: 0,
    inMemoryBytes: 0,
    lastSyncAt: null,
  );

  CacheInfo copyWith({
    int? totalBytes,
    int? imagesBytes,
    int? temporaryBytes,
    int? inMemoryBytes,
    DateTime? lastSyncAt,
    bool clearLastSyncAt = false,
  }) {
    return CacheInfo(
      totalBytes: totalBytes ?? this.totalBytes,
      imagesBytes: imagesBytes ?? this.imagesBytes,
      temporaryBytes: temporaryBytes ?? this.temporaryBytes,
      inMemoryBytes: inMemoryBytes ?? this.inMemoryBytes,
      lastSyncAt: clearLastSyncAt ? null : (lastSyncAt ?? this.lastSyncAt),
    );
  }
}
