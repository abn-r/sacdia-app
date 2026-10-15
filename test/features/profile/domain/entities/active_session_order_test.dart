import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/domain/entities/active_session.dart';

ActiveSession _session(String id, {bool current = false}) => ActiveSession(
      sessionId: id,
      deviceType: SessionDeviceType.unknown,
      createdAt: DateTime(2026, 10, 15),
      lastActiveAt: DateTime(2026, 10, 15),
      isCurrent: current,
      expiresAt: DateTime(2026, 10, 22),
    );

/// The backend orders sessions by creation date, so the current one can sit
/// anywhere in the list. The screen shows it first.
void main() {
  test('puts the current session first and keeps the rest in order', () {
    final sorted = currentSessionFirst([
      _session('a'),
      _session('b'),
      _session('c', current: true),
      _session('d'),
    ]);

    expect(sorted.map((s) => s.sessionId), ['c', 'a', 'b', 'd']);
  });

  test('leaves the order alone when no session is current', () {
    final sorted = currentSessionFirst([_session('a'), _session('b')]);

    expect(sorted.map((s) => s.sessionId), ['a', 'b']);
  });
}
