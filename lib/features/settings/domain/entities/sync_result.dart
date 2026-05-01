import 'package:flutter/foundation.dart';

/// Result of a force-sync operation.
///
/// Returned by [CacheRepository.forceSync]. The sync itself fires
/// invalidations against Riverpod providers synchronously, so this value
/// mostly carries the resulting timestamp and whether the run succeeded.
@immutable
class SyncResult {
  /// Whether every handler completed without throwing.
  final bool success;

  /// UTC timestamp recorded at the end of a successful sync.
  /// Null when [success] is false.
  final DateTime? syncedAt;

  /// Non-null when [success] is false — short, already-translated
  /// message ready for display (or a machine-readable fallback if
  /// translation failed).
  final String? errorMessage;

  const SyncResult({
    required this.success,
    required this.syncedAt,
    required this.errorMessage,
  });

  const SyncResult.ok(DateTime syncedAt)
      : success = true,
        syncedAt = syncedAt,
        errorMessage = null;

  const SyncResult.error(String message)
      : success = false,
        syncedAt = null,
        errorMessage = message;
}
