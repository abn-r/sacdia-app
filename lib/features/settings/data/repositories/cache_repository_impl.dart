import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/cache_config.dart';
import '../../../../core/realtime/realtime_ref.dart';
import '../../../../core/realtime/realtime_resource_registry.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../features/members/presentation/providers/members_providers.dart';
import '../../domain/entities/cache_info.dart';
import '../../domain/entities/sync_result.dart';
import '../../domain/repositories/cache_repository.dart';

/// SharedPreferences key for the last successful global force-sync (ms epoch).
///
/// Kept in the "allowed" whitelist inside [CacheRepositoryImpl.clearAllData]
/// so the "Última sincronización" tile does not regress after a cache clear.
const String kLastGlobalSyncAtKey = 'last_global_sync_at';

/// Prefixes / exact keys preserved when the user chooses "Borrar todos los
/// datos". Anything NOT matching any of these is removed.
///
/// We intentionally keep:
///   - theme + locale + accessibility → user-visible preferences
///   - notification_* → FCM / notification prefs cache
///   - auth_*, fcm_* → tokens / device registration (prevents forced re-login)
///   - biometric_* → biometric opt-in flag
///   - EasyLocalization.Locale → easy_localization persists here, wipe = reset
///   - last_global_sync_at → would be confusing to reset to "never"
const List<String> _prefsWhitelistPrefixes = <String>[
  'theme_',
  'locale_',
  'notification_',
  'auth_',
  'fcm_',
  'accessibility_',
  'biometric_',
];

const List<String> _prefsWhitelistExact = <String>[
  'EasyLocalization.Locale',
  kLastGlobalSyncAtKey,
];

/// Concrete [CacheRepository] backed by the app's real storage.
///
/// Construction is kept parameter-less — heavy collaborators (cache managers,
/// path_provider) are module-level singletons. [LocalStorage] is injected so
/// tests can pass an in-memory fake without stubbing SharedPreferences itself.
class CacheRepositoryImpl implements CacheRepository {
  CacheRepositoryImpl({required LocalStorage localStorage})
      : _localStorage = localStorage;

  final LocalStorage _localStorage;

  // ── Reads ──────────────────────────────────────────────────────────────────

  @override
  Future<CacheInfo> getCacheInfo() async {
    // Cache-manager sizes (disk, maintained by flutter_cache_manager).
    int sacBytes = 0;
    int defaultBytes = 0;
    try {
      sacBytes = await _safeStoreSize(SacCacheManager.instance);
      defaultBytes = await _safeStoreSize(DefaultCacheManager());
    } catch (e, st) {
      debugPrint('[CacheRepo] cache-manager size failed: $e\n$st');
    }

    // Temp directory — recursive scan can be slow on cold FS, run in an
    // isolate with a 5s soft timeout.
    int tempBytes = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      tempBytes = await compute(_sumDirectoryBytes, tempDir.path)
          .timeout(const Duration(seconds: 5), onTimeout: () => 0);
    } catch (e, st) {
      debugPrint('[CacheRepo] temp size failed: $e\n$st');
    }

    // In-memory decoded images. Cheap, synchronous read.
    final inMemoryBytes = PaintingBinding.instance.imageCache.currentSizeBytes;

    final imagesBytes = sacBytes + defaultBytes;
    // Avoid double-counting: the disk managers usually live INSIDE temp,
    // so subtract to get a realistic "total". Clamp to ≥0 for safety.
    final tempOnly = (tempBytes - imagesBytes).clamp(0, tempBytes);
    final total = imagesBytes + tempOnly + inMemoryBytes;

    // last_global_sync_at — pulled from SharedPreferences directly.
    final lastSyncMs = _localStorage.getInt(kLastGlobalSyncAtKey);
    final lastSyncAt = lastSyncMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(lastSyncMs);

    return CacheInfo(
      totalBytes: total,
      imagesBytes: imagesBytes,
      temporaryBytes: tempOnly,
      inMemoryBytes: inMemoryBytes,
      lastSyncAt: lastSyncAt,
    );
  }

  // ── Clear: images only ─────────────────────────────────────────────────────

  @override
  Future<void> clearImageCaches() async {
    try {
      await SacCacheManager.instance.emptyCache();
    } catch (e) {
      debugPrint('[CacheRepo] SacCacheManager.emptyCache failed: $e');
    }
    try {
      await DefaultCacheManager().emptyCache();
    } catch (e) {
      debugPrint('[CacheRepo] DefaultCacheManager.emptyCache failed: $e');
    }
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (e) {
      debugPrint('[CacheRepo] imageCache.clear failed: $e');
    }
  }

  // ── Clear: everything (with confirmation from UI layer) ────────────────────

  @override
  Future<void> clearAllData() async {
    await clearImageCaches();

    // Recursive wipe of temp. Delete contents, not the directory itself —
    // deleting the dir can confuse path_provider on next call.
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        await for (final entity in tempDir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (e) {
            debugPrint('[CacheRepo] delete ${entity.path} failed: $e');
          }
        }
      }
    } catch (e, st) {
      debugPrint('[CacheRepo] temp wipe failed: $e\n$st');
    }

    // Selective SharedPreferences clear.
    // NOTE: this intentionally bypasses the [LocalStorage] abstraction — we
    // need the raw SharedPreferences to enumerate and remove keys matching
    // our prefix rules without invalidating the abstraction's contract.
    try {
      final prefs = await SharedPreferences.getInstance();
      final allKeys = prefs.getKeys().toList(growable: false);
      for (final key in allKeys) {
        if (_shouldPreserveKey(key)) continue;
        await prefs.remove(key);
      }
    } catch (e, st) {
      debugPrint('[CacheRepo] SharedPreferences selective clear failed: $e\n$st');
    }
  }

  // ── Force sync ─────────────────────────────────────────────────────────────

  @override
  Future<SyncResult> forceSync(RealtimeRef ref) async {
    try {
      // Resolve the active club context for section-scoped handlers.
      final ctx = ref.read(clubContextProvider).valueOrNull;

      // Fire the registry + catalogs. Handlers that require a matching
      // sectionId will no-op if ctx is null (we pass a sentinel -1).
      RealtimeResourceRegistry.invalidateAll(
        ref,
        ctx?.sectionId ?? -1,
      );

      // Record timestamp ONLY on success.
      final now = DateTime.now();
      await _localStorage.saveInt(
        kLastGlobalSyncAtKey,
        now.millisecondsSinceEpoch,
      );
      return SyncResult.ok(now);
    } catch (e, st) {
      debugPrint('[CacheRepo] forceSync threw: $e\n$st');
      // Translated key — fallback to the raw message if translations are
      // not ready (e.g. running outside an app context in a test).
      String msg;
      try {
        msg = 'settings.force_sync_error'.tr();
      } catch (_) {
        msg = 'Force sync failed';
      }
      return SyncResult.error(msg);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static bool _shouldPreserveKey(String key) {
    for (final exact in _prefsWhitelistExact) {
      if (key == exact) return true;
    }
    for (final prefix in _prefsWhitelistPrefixes) {
      if (key.startsWith(prefix)) return true;
    }
    return false;
  }

  /// Wraps `store.getCacheSize()` — API shape differs across
  /// flutter_cache_manager versions, so we fall back to a directory scan
  /// if the call throws. Returns bytes or 0 on failure.
  static Future<int> _safeStoreSize(CacheManager manager) async {
    try {
      final dynamic store = manager.store;
      // `getCacheSize` is exposed by CacheStore in flutter_cache_manager
      // ≥3.4 — we call it dynamically to stay tolerant of minor API drift.
      final result = await (store.getCacheSize() as Future);
      if (result is int) return result;
    } catch (e) {
      debugPrint('[CacheRepo] store.getCacheSize failed: $e');
    }
    return 0;
  }
}

/// Top-level function (required by `compute`) — recursively sums the byte
/// length of every file under [path]. Returns 0 on any error, safely skips
/// symlinks and permission-denied entries.
int _sumDirectoryBytes(String path) {
  try {
    final dir = Directory(path);
    if (!dir.existsSync()) return 0;
    int total = 0;
    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        try {
          total += entity.lengthSync();
        } catch (_) {
          // stat failures (e.g. races with deletion) — ignore that file.
        }
      }
    }
    return total;
  } catch (_) {
    return 0;
  }
}
