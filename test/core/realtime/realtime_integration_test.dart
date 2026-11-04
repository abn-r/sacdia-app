/// Integration tests for the realtime invalidation pipeline:
/// - Foreground INVALIDATE → registry dispatch → clubActivitiesProvider invalidated
/// - Unknown resource → no crash, no invalidation
/// - Feature flag disabled → no club invalidation (authorization still runs)
///
/// These tests use ProviderContainer overrides to isolate the provider graph
/// from Firebase and network. The 'activities' registry handler is overridden
/// with a capturing stub so we can assert invalidation without a real network.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/providers/riverpod_aliases.dart';
import 'package:sacdia_app/core/realtime/realtime_invalidation_handler.dart';
import 'package:sacdia_app/core/realtime/realtime_ref.dart';
import 'package:sacdia_app/core/realtime/realtime_resource_registry.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// A [RealtimeRef] that records which (resource, sectionId) pairs were
/// dispatched, without touching the real Riverpod provider graph.
class _SpyRealtimeRef implements RealtimeRef {
  final List<String> dispatched = [];

  @override
  T read<T>(ProviderListenable<T> provider) =>
      throw UnimplementedError('Not used in integration tests');

  @override
  void invalidate(ProviderOrFamily provider) {
    // Intentional no-op — we capture at the registry handler level.
  }
}

RemoteMessage _makeMessage({
  required String resource,
  required String sectionId,
  String type = 'cache_invalidate',
}) {
  return RemoteMessage(
    data: {
      'type': type,
      'resource': resource,
      'sectionId': sectionId,
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // Reset SharedPreferences before each test.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('T4.6 — foreground INVALIDATE dispatches activities invalidation', () {
    late List<String> captured;

    setUp(() {
      captured = [];
      // Override the built-in handler to capture calls without touching Riverpod.
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        captured.add('activities|$sectionId');
      });
    });

    test('valid message with resource=activities dispatches invalidation', () {
      final msg = _makeMessage(resource: 'activities', sectionId: '5');
      final ref = _SpyRealtimeRef();

      RealtimeInvalidationHandler.handleForeground(msg, ref,
          realtimeEnabled: true);

      expect(captured, contains('activities|5'));
    });

    test('correct sectionId is passed to the handler', () {
      final msg = _makeMessage(resource: 'activities', sectionId: '42');
      final ref = _SpyRealtimeRef();

      RealtimeInvalidationHandler.handleForeground(msg, ref,
          realtimeEnabled: true);

      expect(captured.last, 'activities|42');
    });

    test('flag enabled check — dispatch happens when handler is registered',
        () {
      // This test represents the flag=enabled path: the handler itself gates
      // club resources on the flag (`realtimeEnabled`), so the caller
      // (push_notification_service.dart) always calls it. We verify the
      // dispatch happens correctly when the flag is on.
      final msg = _makeMessage(resource: 'activities', sectionId: '7');
      final ref = _SpyRealtimeRef();

      RealtimeInvalidationHandler.handleForeground(msg, ref,
          realtimeEnabled: true);

      expect(captured, isNotEmpty);
      expect(captured.first, 'activities|7');
    });
  });

  group('T4.7 — unknown resource and flag=disabled scenarios', () {
    late List<String> captured;

    setUp(() {
      captured = [];
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        captured.add('activities|$sectionId');
      });
    });

    test('unknown resource does not throw and produces no dispatch', () {
      final msg = _makeMessage(resource: 'unknown_thing', sectionId: '3');
      final ref = _SpyRealtimeRef();

      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref),
        returnsNormally,
      );
      expect(captured, isEmpty);
    });

    test('flag=disabled path — a club resource is NOT dispatched', () {
      // The compile-time flag is off unless defined with --dart-define, which
      // is exactly the production default: the handler receives the message
      // (push_notification_service.dart no longer checks the flag) and
      // ignores club resources by itself.
      final msg = _makeMessage(resource: 'activities', sectionId: '7');
      final ref = _SpyRealtimeRef();

      RealtimeInvalidationHandler.handleForeground(msg, ref);
      expect(captured, isEmpty);

      RealtimeInvalidationHandler.handleForeground(msg, ref,
          realtimeEnabled: false);
      expect(captured, isEmpty);
    });

    test('flag=disabled path — a club resource is NOT staged', () async {
      final msg = _makeMessage(resource: 'activities', sectionId: '7');

      await RealtimeInvalidationHandler.stagePending(msg);
      await RealtimeInvalidationHandler.stagePending(msg,
          realtimeEnabled: false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('pending_realtime_invalidations'), isFalse);
    });

    test('message with missing resource does not throw', () {
      final msg = RemoteMessage(
        data: {'type': 'cache_invalidate', 'sectionId': '1'},
      );
      final ref = _SpyRealtimeRef();

      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref),
        returnsNormally,
      );
      expect(captured, isEmpty);
    });

    test('message with malformed sectionId does not throw', () {
      final msg = RemoteMessage(
        data: {
          'type': 'cache_invalidate',
          'resource': 'activities',
          'sectionId': 'abc',
        },
      );
      final ref = _SpyRealtimeRef();

      expect(
        () => RealtimeInvalidationHandler.handleForeground(msg, ref),
        returnsNormally,
      );
      expect(captured, isEmpty);
    });
  });
}
