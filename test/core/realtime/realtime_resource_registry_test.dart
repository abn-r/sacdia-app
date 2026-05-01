import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/realtime/realtime_ref.dart';
import 'package:sacdia_app/core/realtime/realtime_resource_registry.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Minimal [RealtimeRef] stub for registry tests.
/// Handlers registered in setUp override the real 'activities' handler and
/// ignore the ref parameter, so this can be a no-op implementation.
class _StubRealtimeRef implements RealtimeRef {
  @override
  T read<T>(ProviderListenable<T> provider) =>
      throw UnimplementedError('Not needed in registry tests');

  @override
  void invalidate(ProviderOrFamily provider) {
    // no-op — registry tests override handlers so this is never called
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('RealtimeResourceRegistry', () {
    late _StubRealtimeRef stubRef;
    late List<String> callLog;

    setUp(() {
      stubRef = _StubRealtimeRef();
      callLog = [];

      // Override 'activities' handler to capture dispatch calls.
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        callLog.add('activities|$sectionId');
      });
    });

    test('dispatches known resource to registered handler', () {
      RealtimeResourceRegistry.invalidate(stubRef, 'activities', 42);
      expect(callLog, contains('activities|42'));
    });

    test('handler receives correct sectionId', () {
      RealtimeResourceRegistry.invalidate(stubRef, 'activities', 99);
      expect(callLog.last, 'activities|99');
    });

    test('unknown resource does not throw and logs warning', () {
      // Should complete without throwing.
      expect(
        () => RealtimeResourceRegistry.invalidate(
            stubRef, 'unknown_resource', 1),
        returnsNormally,
      );
      // No dispatch should have been recorded.
      expect(callLog, isEmpty);
    });

    test('register() replaces existing handler', () {
      final secondLog = <String>[];
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        secondLog.add('new|$sectionId');
      });

      RealtimeResourceRegistry.invalidate(stubRef, 'activities', 5);

      // Old log still empty; new handler captured the call.
      expect(callLog, isEmpty);
      expect(secondLog, contains('new|5'));

      // Restore the test handler for other tests.
      RealtimeResourceRegistry.register('activities', (ref, sectionId) {
        callLog.add('activities|$sectionId');
      });
    });

    test('multiple calls dispatch independently', () {
      RealtimeResourceRegistry.invalidate(stubRef, 'activities', 1);
      RealtimeResourceRegistry.invalidate(stubRef, 'activities', 2);
      RealtimeResourceRegistry.invalidate(stubRef, 'activities', 3);

      expect(
        callLog,
        containsAll(['activities|1', 'activities|2', 'activities|3']),
      );
    });
  });
}
