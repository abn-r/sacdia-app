import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/realtime/feature_flags.dart';
import 'package:sacdia_app/core/realtime/realtime_invalidation_handler.dart';
import 'package:sacdia_app/core/realtime/realtime_ref.dart';
import 'package:sacdia_app/core/realtime/realtime_resource_registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal [RealtimeRef] stub that captures invalidate calls.
class _CapturingRealtimeRef implements RealtimeRef {
  final List<String> invalidated = [];

  @override
  T read<T>(ProviderListenable<T> provider) =>
      throw UnimplementedError('Not needed in handler tests');

  @override
  void invalidate(ProviderOrFamily provider) {
    invalidated.add(provider.toString());
  }
}

/// Builds a minimal [RemoteMessage] carrying a cache_invalidate data payload.
RemoteMessage _buildInvalidateMessage({
  required String resource,
  required String sectionId,
  String? timestamp,
  String type = 'cache_invalidate',
}) {
  return RemoteMessage(
    data: {
      'type': type,
      'resource': resource,
      'sectionId': sectionId,
      if (timestamp != null) 'timestamp': timestamp,
    },
  );
}

/// Reads the raw JSON list stored under the pending invalidations key.
Future<List<Map<String, String>>> _readQueue() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('pending_realtime_invalidations');
  if (raw == null || raw.isEmpty) return [];
  final decoded = jsonDecode(raw) as List<dynamic>;
  return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests — stagePending
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('RealtimeInvalidationHandler — stagePending', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('stores a single entry in the queue', () async {
      final msg = _buildInvalidateMessage(
        resource: 'activities',
        sectionId: '7',
        timestamp: '2025-01-01T10:00:00Z',
      );

      await RealtimeInvalidationHandler.stagePending(msg,
          realtimeEnabled: true);

      final queue = await _readQueue();
      expect(queue.length, 1);
      expect(queue.first['resource'], 'activities');
      expect(queue.first['sectionId'], '7');
      expect(queue.first['timestamp'], '2025-01-01T10:00:00Z');
    });

    test('appends to existing entries rather than overwriting', () async {
      // Stage first entry.
      await RealtimeInvalidationHandler.stagePending(
        _buildInvalidateMessage(
          resource: 'activities',
          sectionId: '1',
          timestamp: '2025-01-01T09:00:00Z',
        ),
        realtimeEnabled: true,
      );

      // Stage second entry with a different section.
      await RealtimeInvalidationHandler.stagePending(
        _buildInvalidateMessage(
          resource: 'activities',
          sectionId: '2',
          timestamp: '2025-01-01T09:01:00Z',
        ),
        realtimeEnabled: true,
      );

      final queue = await _readQueue();
      expect(queue.length, 2);
      expect(queue[0]['sectionId'], '1');
      expect(queue[1]['sectionId'], '2');
    });

    test('handles missing resource field gracefully (no throw)', () async {
      final msg = RemoteMessage(
        data: {'type': 'cache_invalidate', 'sectionId': '5'},
      );
      await expectLater(
        RealtimeInvalidationHandler.stagePending(msg, realtimeEnabled: true),
        completes,
      );
      // Queue must remain empty.
      expect(await _readQueue(), isEmpty);
    });

    test('handles missing sectionId field gracefully (no throw)', () async {
      final msg = RemoteMessage(
        data: {'type': 'cache_invalidate', 'resource': 'activities'},
      );
      await expectLater(
        RealtimeInvalidationHandler.stagePending(msg, realtimeEnabled: true),
        completes,
      );
      expect(await _readQueue(), isEmpty);
    });

    test('recovers from malformed JSON in existing queue', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': 'NOT_VALID_JSON',
      });

      final msg = _buildInvalidateMessage(
        resource: 'activities',
        sectionId: '3',
        timestamp: '2025-01-01T10:00:00Z',
      );
      await RealtimeInvalidationHandler.stagePending(msg,
          realtimeEnabled: true);

      final queue = await _readQueue();
      // After corruption recovery, only the new entry should be present.
      expect(queue.length, 1);
      expect(queue.first['sectionId'], '3');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Tests — drainPending
  // ─────────────────────────────────────────────────────────────────────────

  group('RealtimeInvalidationHandler — drainPending', () {
    late List<String> dispatchedKeys;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dispatchedKeys = [];

      // Override the 'activities' handler in the registry to capture calls.
      // The handler ignores the ref and captures the sectionId.
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        dispatchedKeys.add('activities|$sectionId');
      });
    });

    test('dispatches each unique (resource, section_id) pair', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {
            'resource': 'activities',
            'sectionId': '1',
            'timestamp': '2025-01-01T10:00:00Z',
          },
          {
            'resource': 'activities',
            'sectionId': '2',
            'timestamp': '2025-01-01T10:01:00Z',
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref,
          realtimeEnabled: true);

      expect(dispatchedKeys, contains('activities|1'));
      expect(dispatchedKeys, contains('activities|2'));
    });

    test('deduplicates by (resource, section_id) keeping latest timestamp',
        () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {
            'resource': 'activities',
            'sectionId': '5',
            'timestamp': '2025-01-01T10:00:00Z',
          },
          {
            'resource': 'activities',
            'sectionId': '5',
            'timestamp': '2025-01-01T10:30:00Z', // later — should win
          },
          {
            'resource': 'activities',
            'sectionId': '5',
            'timestamp': '2025-01-01T09:00:00Z', // earlier — should be dropped
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref,
          realtimeEnabled: true);

      // Despite 3 entries for section 5, the handler should be called exactly once.
      expect(dispatchedKeys.where((k) => k == 'activities|5').length, 1);
    });

    test('clears the SharedPreferences key after draining', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {
            'resource': 'activities',
            'sectionId': '3',
            'timestamp': '2025-01-01T10:00:00Z',
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref,
          realtimeEnabled: true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_realtime_invalidations'), isFalse);
    });

    test('handles empty queue gracefully', () async {
      final ref = _CapturingRealtimeRef();
      await expectLater(
        RealtimeInvalidationHandler.drainPending(ref, realtimeEnabled: true),
        completes,
      );
    });

    test('handles malformed JSON in queue gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': 'CORRUPTED',
      });

      final ref = _CapturingRealtimeRef();
      await expectLater(
        RealtimeInvalidationHandler.drainPending(ref, realtimeEnabled: true),
        completes,
      );

      // Queue should be cleared.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_realtime_invalidations'), isFalse);

      // No dispatches should have happened.
      expect(dispatchedKeys, isEmpty);
    });

    test('skips entries with non-integer section_id', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {
            'resource': 'activities',
            'sectionId': 'not-a-number',
            'timestamp': '2025-01-01T10:00:00Z',
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref,
          realtimeEnabled: true);

      // No dispatches — invalid section_id is skipped.
      expect(dispatchedKeys, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Tests — handleForeground
  // ─────────────────────────────────────────────────────────────────────────

  group('RealtimeInvalidationHandler — handleForeground', () {
    late List<String> dispatchedKeys;

    setUp(() {
      dispatchedKeys = [];
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        dispatchedKeys.add('activities|$sectionId');
      });
    });

    test('dispatches valid INVALIDATE message to registry', () {
      final msg = _buildInvalidateMessage(
        resource: 'activities',
        sectionId: '10',
      );
      final ref = _CapturingRealtimeRef();
      RealtimeInvalidationHandler.handleForeground(msg, ref,
          realtimeEnabled: true);

      expect(dispatchedKeys, contains('activities|10'));
    });

    test('ignores message with missing resource field', () {
      final msg = RemoteMessage(
        data: {'type': 'cache_invalidate', 'sectionId': '5'},
      );
      final ref = _CapturingRealtimeRef();
      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref,
            realtimeEnabled: true),
        returnsNormally,
      );
      expect(dispatchedKeys, isEmpty);
    });

    test('ignores message with non-integer sectionId', () {
      final msg = RemoteMessage(
        data: {
          'type': 'cache_invalidate',
          'resource': 'activities',
          'sectionId': 'bad',
        },
      );
      final ref = _CapturingRealtimeRef();
      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref,
            realtimeEnabled: true),
        returnsNormally,
      );
      expect(dispatchedKeys, isEmpty);
    });

    test('unknown resource does not throw', () {
      final msg = RemoteMessage(
        data: {
          'type': 'cache_invalidate',
          'resource': 'nonexistent',
          'sectionId': '1',
        },
      );
      final ref = _CapturingRealtimeRef();
      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref,
            realtimeEnabled: true),
        returnsNormally,
      );
      expect(dispatchedKeys, isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Tests — resource 'authorization' (phase 7)
  // ─────────────────────────────────────────────────────────────────────────

  group('RealtimeInvalidationHandler — authorization resource', () {
    late int refreshes;
    late List<String> dispatchedKeys;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      refreshes = 0;
      dispatchedKeys = [];
      RealtimeInvalidationHandler.onAuthorizationInvalidate =
          (_) => refreshes++;
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        dispatchedKeys.add('activities|$sectionId');
      });
    });

    tearDown(() {
      RealtimeInvalidationHandler.onAuthorizationInvalidate =
          RealtimeInvalidationHandler.refreshAuthorization;
    });

    test('foreground: refreshes /auth/me even without a sectionId', () {
      final msg = RemoteMessage(
        data: {
          'type': 'cache_invalidate',
          'resource': 'authorization',
          'action': 'UPDATED',
          'timestamp': '2026-11-04T10:00:00Z',
        },
      );
      RealtimeInvalidationHandler.handleForeground(
          msg, _CapturingRealtimeRef());

      expect(refreshes, 1);
      expect(dispatchedKeys, isEmpty, reason: 'never reaches the registry');
    });

    test('background: the message is staged without a sectionId', () async {
      await RealtimeInvalidationHandler.stagePending(
        RemoteMessage(
          data: {
            'type': 'cache_invalidate',
            'resource': 'authorization',
            'action': 'UPDATED',
            'timestamp': '2026-11-04T10:00:00Z',
          },
        ),
      );
      final queue = await _readQueue();
      expect(queue.length, 1);
      expect(queue.single['resource'], 'authorization');
      expect(queue.single.containsKey('sectionId'), isFalse);
      expect(queue.single['timestamp'], '2026-11-04T10:00:00Z');
    });

    test('drain: a staged authorization entry refreshes once, before sectionId',
        () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {'resource': 'authorization', 'timestamp': '2026-11-04T10:00:00Z'},
          {'resource': 'authorization', 'timestamp': '2026-11-04T10:05:00Z'},
          {
            'resource': 'activities',
            'sectionId': '3',
            'timestamp': '2026-11-04T10:01:00Z',
          },
        ]),
      });

      await RealtimeInvalidationHandler.drainPending(
        _CapturingRealtimeRef(),
        realtimeEnabled: true,
      );

      expect(refreshes, 1);
      expect(dispatchedKeys, ['activities|3']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_realtime_invalidations'), isFalse);
    });

    test('a throwing refresher never breaks the handler', () {
      RealtimeInvalidationHandler.onAuthorizationInvalidate =
          (_) => throw StateError('boom');
      expect(
        () => RealtimeInvalidationHandler.handleForeground(
          RemoteMessage(
            data: {'type': 'cache_invalidate', 'resource': 'authorization'},
          ),
          _CapturingRealtimeRef(),
        ),
        returnsNormally,
      );
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Tests — feature flag gate lives in the handler
  // ─────────────────────────────────────────────────────────────────────────

  group('RealtimeInvalidationHandler — feature flag gate', () {
    late int refreshes;
    late List<String> dispatchedKeys;

    RemoteMessage authorization() => RemoteMessage(
          data: {
            'type': 'cache_invalidate',
            'resource': 'authorization',
            'action': 'UPDATED',
            'timestamp': '2026-11-04T10:00:00Z',
          },
        );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      refreshes = 0;
      dispatchedKeys = [];
      RealtimeInvalidationHandler.onAuthorizationInvalidate =
          (_) => refreshes++;
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        dispatchedKeys.add('activities|$sectionId');
      });
    });

    tearDown(() {
      RealtimeInvalidationHandler.onAuthorizationInvalidate =
          RealtimeInvalidationHandler.refreshAuthorization;
    });

    test('shouldHandleResource: authorization always, club resources by flag',
        () {
      expect(
        RealtimeInvalidationHandler.shouldHandleResource('authorization',
            realtimeEnabled: false),
        isTrue,
      );
      expect(
        RealtimeInvalidationHandler.shouldHandleResource('activities',
            realtimeEnabled: false),
        isFalse,
      );
      expect(
        RealtimeInvalidationHandler.shouldHandleResource('activities',
            realtimeEnabled: true),
        isTrue,
      );
      expect(
        RealtimeInvalidationHandler.shouldHandleResource(null,
            realtimeEnabled: false),
        isFalse,
      );
      // Default = the compile-time flag, which is off unless defined.
      expect(RealtimeInvalidationHandler.shouldHandle(authorization()), isTrue);
      expect(
        RealtimeInvalidationHandler.shouldHandle(
          _buildInvalidateMessage(resource: 'activities', sectionId: '1'),
        ),
        RealtimeFeatureFlags.realtimeInvalidationEnabled,
      );
    });

    test('foreground: authorization is processed with the flag off', () {
      RealtimeInvalidationHandler.handleForeground(
        authorization(),
        _CapturingRealtimeRef(),
        realtimeEnabled: false,
      );
      expect(refreshes, 1);

      // And with the default (compile-time) flag, which is off by default.
      RealtimeInvalidationHandler.handleForeground(
        authorization(),
        _CapturingRealtimeRef(),
      );
      expect(refreshes, 2);
    });

    test('foreground: a club resource is ignored with the flag off', () {
      final msg =
          _buildInvalidateMessage(resource: 'activities', sectionId: '3');
      RealtimeInvalidationHandler.handleForeground(
        msg,
        _CapturingRealtimeRef(),
        realtimeEnabled: false,
      );
      expect(dispatchedKeys, isEmpty);
      expect(refreshes, 0);
    });

    test('background: authorization is staged with the flag off', () async {
      await RealtimeInvalidationHandler.stagePending(
        authorization(),
        realtimeEnabled: false,
      );
      final queue = await _readQueue();
      expect(queue.length, 1);
      expect(queue.single['resource'], 'authorization');
    });

    test('background: a club resource is not staged with the flag off',
        () async {
      await RealtimeInvalidationHandler.stagePending(
        _buildInvalidateMessage(resource: 'activities', sectionId: '3'),
        realtimeEnabled: false,
      );
      expect(await _readQueue(), isEmpty);
    });

    test('drain: with the flag off only authorization is dispatched', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {'resource': 'authorization', 'timestamp': '2026-11-04T10:00:00Z'},
          {
            'resource': 'activities',
            'sectionId': '3',
            'timestamp': '2026-11-04T10:01:00Z',
          },
        ]),
      });

      await RealtimeInvalidationHandler.drainPending(
        _CapturingRealtimeRef(),
        realtimeEnabled: false,
      );

      expect(refreshes, 1);
      expect(dispatchedKeys, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.containsKey('pending_realtime_invalidations'),
        isFalse,
        reason: 'the queue is cleared even for ignored entries',
      );
    });
  });
}
