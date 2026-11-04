import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../utils/app_logger.dart';
import 'feature_flags.dart';
import 'realtime_ref.dart';
import 'realtime_resource_registry.dart';

/// Handles the two paths for realtime cache invalidation via FCM data messages.
///
/// ## Foreground path
/// When the app is in the foreground Riverpod is live. [handleForeground]
/// parses the FCM payload and immediately calls [RealtimeResourceRegistry].
///
/// ## Background path
/// Riverpod providers are NOT accessible from the background isolate that
/// Firebase uses for [firebaseMessagingBackgroundHandler]. Instead, [stagePending]
/// serialises the invalidation request to [SharedPreferences]. On the next
/// app resume [drainPending] reads, deduplicates and processes the queue.
///
/// ## Deduplication
/// Multiple background messages for the same (resource, sectionId) pair are
/// collapsed into one — keeping the entry with the latest timestamp. This
/// prevents redundant network fetches when several mutations arrive while the
/// app is backgrounded.
///
/// ## Feature flag
/// The handler itself decides what to process (see [shouldHandleResource]):
/// the `authorization` push is part of the phase 7 contract and is ALWAYS
/// handled; club-data resources (those carrying a `sectionId`) stay behind
/// [RealtimeFeatureFlags.realtimeInvalidationEnabled]. Callers
/// (`push_notification_service.dart`, `main.dart`) never consult the flag.
class RealtimeInvalidationHandler {
  RealtimeInvalidationHandler._();

  static const _tag = 'RealtimeInvalidation';
  static const _prefsKey = 'pending_realtime_invalidations';

  /// Recurso del push silencioso que avisa de un cambio de autorización del
  /// usuario (`{type: 'cache_invalidate', resource: 'authorization',
  /// action: 'UPDATED', timestamp}`). No lleva `sectionId`: se dirige al
  /// usuario afectado y la respuesta es volver a pedir `/auth/me`.
  static const authorizationResource = 'authorization';

  /// ¿Se procesa un `cache_invalidate` de [resource]?
  ///
  /// `authorization` siempre: no depende de la bandera. El resto (datos de
  /// club con `sectionId`) solo con [realtimeEnabled], que por defecto es
  /// [RealtimeFeatureFlags.realtimeInvalidationEnabled] (constante de
  /// compilación); los tests la inyectan.
  static bool shouldHandleResource(
    String? resource, {
    bool realtimeEnabled = RealtimeFeatureFlags.realtimeInvalidationEnabled,
  }) {
    return resource == authorizationResource || realtimeEnabled;
  }

  /// [shouldHandleResource] leyendo `resource` de [msg.data].
  static bool shouldHandle(
    RemoteMessage msg, {
    bool realtimeEnabled = RealtimeFeatureFlags.realtimeInvalidationEnabled,
  }) {
    return shouldHandleResource(
      msg.data['resource'] as String?,
      realtimeEnabled: realtimeEnabled,
    );
  }

  /// Qué hacer ante un `authorization` recibido en primer plano o drenado al
  /// volver al frente. Por defecto vuelve a pedir `/auth/me` sin esperar el
  /// intervalo mínimo. Los tests lo sustituyen para capturar la llamada.
  @visibleForTesting
  static void Function(RealtimeRef ref) onAuthorizationInvalidate =
      refreshAuthorization;

  /// Implementación por defecto de [onAuthorizationInvalidate]: vuelve a pedir
  /// `/auth/me` en todos los modos, sin esperar el intervalo mínimo.
  static void refreshAuthorization(RealtimeRef ref) {
    unawaited(
      ref
          .read(authNotifierProvider.notifier)
          .refreshAuthorization(minInterval: Duration.zero),
    );
  }

  static void _handleAuthorization(RealtimeRef ref, String origin) {
    AppLogger.i('Autorización cambiada ($origin): refrescando /auth/me',
        tag: _tag);
    try {
      onAuthorizationInvalidate(ref);
    } catch (e, st) {
      AppLogger.e(
        'Error al refrescar la autorización',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Foreground ─────────────────────────────────────────────────────────────

  /// Called when the app is in the foreground and an INVALIDATE FCM message
  /// arrives (via [FirebaseMessaging.onMessage]).
  ///
  /// Parses [resource] and [sectionId] from [msg.data], then delegates to
  /// [RealtimeResourceRegistry]. Errors are caught and logged — a bad payload
  /// must never crash the app. Resources behind the flag are ignored unless
  /// [realtimeEnabled] (see [shouldHandleResource]).
  static void handleForeground(
    RemoteMessage msg,
    RealtimeRef ref, {
    bool realtimeEnabled = RealtimeFeatureFlags.realtimeInvalidationEnabled,
  }) {
    try {
      final data = msg.data;
      // Discriminator matches backend `type: 'cache_invalidate'` from
      // notifications.processor.ts sendSilentMulticast.
      final resource = data['resource'] as String?;
      final rawSectionId = data['sectionId'] as String?;

      if (!shouldHandleResource(resource, realtimeEnabled: realtimeEnabled)) {
        AppLogger.d(
          'Foreground invalidation ignored (flag off): resource=$resource',
          tag: _tag,
        );
        return;
      }

      // Sin `sectionId` por contrato: se resuelve antes de exigirlo.
      if (resource == authorizationResource) {
        _handleAuthorization(ref, 'foreground');
        return;
      }

      if (resource == null || rawSectionId == null) {
        AppLogger.w(
          'cache_invalidate message missing resource or sectionId fields',
          tag: _tag,
        );
        return;
      }

      final sectionId = int.tryParse(rawSectionId);
      if (sectionId == null) {
        AppLogger.w(
          'cache_invalidate message has non-integer sectionId: "$rawSectionId"',
          tag: _tag,
        );
        return;
      }

      AppLogger.i(
        'Foreground invalidation: resource=$resource sectionId=$sectionId',
        tag: _tag,
      );

      RealtimeResourceRegistry.invalidate(ref, resource, sectionId);
    } catch (e, st) {
      AppLogger.e(
        'Unexpected error handling foreground INVALIDATE message',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Background staging ─────────────────────────────────────────────────────

  /// Appends the INVALIDATE payload from [msg] to the pending queue in
  /// [SharedPreferences].
  ///
  /// Called from the top-level [firebaseMessagingBackgroundHandler] where
  /// Riverpod is not available. Errors are caught so the background isolate
  /// never crashes. Resources behind the flag are not staged unless
  /// [realtimeEnabled] (see [shouldHandleResource]).
  ///
  /// Un `authorization` se encola sin `sectionId` (no lo lleva por contrato):
  /// al drenar, la app vuelve a pedir `/auth/me` sin esperar el intervalo
  /// mínimo, aunque el refresco de `resumed` ya se hubiera saltado por él.
  static Future<void> stagePending(
    RemoteMessage msg, {
    bool realtimeEnabled = RealtimeFeatureFlags.realtimeInvalidationEnabled,
  }) async {
    try {
      final data = msg.data;
      final resource = data['resource'] as String?;
      final sectionId = data['sectionId'] as String?;
      final timestamp =
          data['timestamp'] as String? ?? DateTime.now().toIso8601String();

      if (!shouldHandleResource(resource, realtimeEnabled: realtimeEnabled)) {
        AppLogger.d(
          'Background invalidation ignored (flag off): resource=$resource',
          tag: _tag,
        );
        return;
      }

      final isAuthorization = resource == authorizationResource;
      if (resource == null || (sectionId == null && !isAuthorization)) {
        AppLogger.w(
          'Background cache_invalidate message missing resource or sectionId',
          tag: _tag,
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_prefsKey);

      List<Map<String, String>> queue = [];
      if (existing != null && existing.isNotEmpty) {
        try {
          final decoded = jsonDecode(existing) as List<dynamic>;
          queue =
              decoded.map((e) => Map<String, String>.from(e as Map)).toList();
        } catch (_) {
          // Malformed stored data — start fresh.
          queue = [];
        }
      }

      queue.add({
        'resource': resource,
        if (sectionId != null) 'sectionId': sectionId,
        'timestamp': timestamp,
      });

      await prefs.setString(_prefsKey, jsonEncode(queue));

      AppLogger.i(
        'Staged background invalidation: resource=$resource '
        'sectionId=${sectionId ?? '-'}',
        tag: _tag,
      );
    } catch (e, st) {
      AppLogger.e(
        'Failed to stage background INVALIDATE message',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Drain on resume ────────────────────────────────────────────────────────

  /// Reads the pending queue from [SharedPreferences], deduplicates entries by
  /// (resource, sectionId) keeping the latest timestamp, dispatches each
  /// to [RealtimeResourceRegistry], then clears the queue.
  ///
  /// Call this from an [AppLifecycleState.resumed] observer so background
  /// invalidations are processed the moment the user brings the app to front.
  ///
  /// Errors are caught so a corrupt queue never breaks the resume path.
  /// Entries for resources behind the flag are dropped unless
  /// [realtimeEnabled] (see [shouldHandleResource]); the queue is cleared
  /// either way.
  static Future<void> drainPending(
    RealtimeRef ref, {
    bool realtimeEnabled = RealtimeFeatureFlags.realtimeInvalidationEnabled,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);

      if (raw == null || raw.isEmpty) return;

      List<Map<String, String>> queue;
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        queue = decoded.map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (e) {
        AppLogger.w(
          'Pending invalidation queue is malformed — clearing',
          tag: _tag,
          error: e,
        );
        await prefs.remove(_prefsKey);
        return;
      }

      if (queue.isEmpty) {
        await prefs.remove(_prefsKey);
        return;
      }

      // Deduplicate: keep the entry with the latest timestamp per (resource, sectionId) pair.
      final Map<String, Map<String, String>> best = {};
      for (final entry in queue) {
        final resource = entry['resource'];
        if (!shouldHandleResource(resource, realtimeEnabled: realtimeEnabled)) {
          continue;
        }
        // `authorization` no lleva sección: una sola entrada basta.
        final sectionId = resource == authorizationResource
            ? (entry['sectionId'] ?? '')
            : entry['sectionId'];
        if (resource == null || sectionId == null) continue;

        final key = '$resource|$sectionId';
        final existing = best[key];
        if (existing == null) {
          best[key] = entry;
        } else {
          // Compare timestamps — prefer the later one.
          final existingTs = existing['timestamp'] ?? '';
          final candidateTs = entry['timestamp'] ?? '';
          if (candidateTs.compareTo(existingTs) > 0) {
            best[key] = entry;
          }
        }
      }

      AppLogger.i(
        'Draining ${best.length} pending invalidation(s) '
        '(${queue.length} raw entries)',
        tag: _tag,
      );

      // Clear the queue before dispatching so a crash mid-drain doesn't
      // cause duplicated invalidations on the next resume.
      await prefs.remove(_prefsKey);

      for (final entry in best.values) {
        final resource = entry['resource']!;
        if (resource == authorizationResource) {
          _handleAuthorization(ref, 'drain');
          continue;
        }
        final rawSectionId = entry['sectionId'] ?? '';
        final sectionId = int.tryParse(rawSectionId);

        if (sectionId == null) {
          AppLogger.w(
            'Skipping drained entry with invalid sectionId: "$rawSectionId"',
            tag: _tag,
          );
          continue;
        }

        RealtimeResourceRegistry.invalidate(ref, resource, sectionId);
      }
    } catch (e, st) {
      AppLogger.e(
        'Unexpected error draining pending invalidations',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }
  }
}
