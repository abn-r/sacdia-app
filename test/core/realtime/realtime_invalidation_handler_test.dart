import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

/// Builds a minimal [RemoteMessage] carrying an INVALIDATE data payload.
RemoteMessage _buildInvalidateMessage({
  required String resource,
  required String sectionId,
  String? timestamp,
  String action = 'INVALIDATE',
}) {
  return RemoteMessage(
    data: {
      'action': action,
      'resource': resource,
      'section_id': sectionId,
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

      await RealtimeInvalidationHandler.stagePending(msg);

      final queue = await _readQueue();
      expect(queue.length, 1);
      expect(queue.first['resource'], 'activities');
      expect(queue.first['section_id'], '7');
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
      );

      // Stage second entry with a different section.
      await RealtimeInvalidationHandler.stagePending(
        _buildInvalidateMessage(
          resource: 'activities',
          sectionId: '2',
          timestamp: '2025-01-01T09:01:00Z',
        ),
      );

      final queue = await _readQueue();
      expect(queue.length, 2);
      expect(queue[0]['section_id'], '1');
      expect(queue[1]['section_id'], '2');
    });

    test('handles missing resource field gracefully (no throw)', () async {
      final msg = RemoteMessage(
        data: {'action': 'INVALIDATE', 'section_id': '5'},
      );
      await expectLater(
        RealtimeInvalidationHandler.stagePending(msg),
        completes,
      );
      // Queue must remain empty.
      expect(await _readQueue(), isEmpty);
    });

    test('handles missing section_id field gracefully (no throw)', () async {
      final msg = RemoteMessage(
        data: {'action': 'INVALIDATE', 'resource': 'activities'},
      );
      await expectLater(
        RealtimeInvalidationHandler.stagePending(msg),
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
      await RealtimeInvalidationHandler.stagePending(msg);

      final queue = await _readQueue();
      // After corruption recovery, only the new entry should be present.
      expect(queue.length, 1);
      expect(queue.first['section_id'], '3');
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
            'section_id': '1',
            'timestamp': '2025-01-01T10:00:00Z',
          },
          {
            'resource': 'activities',
            'section_id': '2',
            'timestamp': '2025-01-01T10:01:00Z',
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref);

      expect(dispatchedKeys, contains('activities|1'));
      expect(dispatchedKeys, contains('activities|2'));
    });

    test('deduplicates by (resource, section_id) keeping latest timestamp',
        () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {
            'resource': 'activities',
            'section_id': '5',
            'timestamp': '2025-01-01T10:00:00Z',
          },
          {
            'resource': 'activities',
            'section_id': '5',
            'timestamp': '2025-01-01T10:30:00Z', // later — should win
          },
          {
            'resource': 'activities',
            'section_id': '5',
            'timestamp': '2025-01-01T09:00:00Z', // earlier — should be dropped
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref);

      // Despite 3 entries for section 5, the handler should be called exactly once.
      expect(dispatchedKeys.where((k) => k == 'activities|5').length, 1);
    });

    test('clears the SharedPreferences key after draining', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': jsonEncode([
          {
            'resource': 'activities',
            'section_id': '3',
            'timestamp': '2025-01-01T10:00:00Z',
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_realtime_invalidations'), isFalse);
    });

    test('handles empty queue gracefully', () async {
      final ref = _CapturingRealtimeRef();
      await expectLater(
        RealtimeInvalidationHandler.drainPending(ref),
        completes,
      );
    });

    test('handles malformed JSON in queue gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'pending_realtime_invalidations': 'CORRUPTED',
      });

      final ref = _CapturingRealtimeRef();
      await expectLater(
        RealtimeInvalidationHandler.drainPending(ref),
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
            'section_id': 'not-a-number',
            'timestamp': '2025-01-01T10:00:00Z',
          },
        ]),
      });

      final ref = _CapturingRealtimeRef();
      await RealtimeInvalidationHandler.drainPending(ref);

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
      RealtimeInvalidationHandler.handleForeground(msg, ref);

      expect(dispatchedKeys, contains('activities|10'));
    });

    test('ignores message with missing resource field', () {
      final msg = RemoteMessage(
        data: {'action': 'INVALIDATE', 'section_id': '5'},
      );
      final ref = _CapturingRealtimeRef();
      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref),
        returnsNormally,
      );
      expect(dispatchedKeys, isEmpty);
    });

    test('ignores message with non-integer section_id', () {
      final msg = RemoteMessage(
        data: {
          'action': 'INVALIDATE',
          'resource': 'activities',
          'section_id': 'bad',
        },
      );
      final ref = _CapturingRealtimeRef();
      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref),
        returnsNormally,
      );
      expect(dispatchedKeys, isEmpty);
    });

    test('unknown resource does not throw', () {
      final msg = RemoteMessage(
        data: {
          'action': 'INVALIDATE',
          'resource': 'nonexistent',
          'section_id': '1',
        },
      );
      final ref = _CapturingRealtimeRef();
      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref),
        returnsNormally,
      );
      expect(dispatchedKeys, isEmpty);
    });
  });
}
