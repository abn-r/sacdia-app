import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/persona/nav_slot.dart';
import 'package:sacdia_app/core/persona/widgets/nav_badge.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Pumps a [NavBadge] with an overridden [unreadNotificationsCountProvider].
Future<void> _pumpBadge(
  WidgetTester tester, {
  required NavBadgeSource source,
  required int count,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        unreadNotificationsCountProvider.overrideWith(
          () => _FakeCountNotifier(count),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: NavBadge(
              source: source,
              child: const Icon(Icons.home),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FakeCountNotifier extends UnreadNotificationsCountNotifier {
  final int _value;
  _FakeCountNotifier(this._value);

  @override
  int build() => _value;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('NavBadge (T-12)', () {
    testWidgets('shows badge when source=activities and count > 0',
        (tester) async {
      await _pumpBadge(
        tester,
        source: NavBadgeSource.activities,
        count: 3,
      );

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows badge when source=members and count > 0',
        (tester) async {
      await _pumpBadge(
        tester,
        source: NavBadgeSource.members,
        count: 5,
      );

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('does NOT show badge when count == 0', (tester) async {
      await _pumpBadge(
        tester,
        source: NavBadgeSource.activities,
        count: 0,
      );

      // Badge text not rendered when count is zero
      expect(find.text('0'), findsNothing);
    });

    testWidgets('does NOT show badge when source == none (count ignored)',
        (tester) async {
      await _pumpBadge(
        tester,
        source: NavBadgeSource.none,
        count: 99,
      );

      // Badge should not appear regardless of count when source is none
      expect(find.text('99'), findsNothing);
    });

    testWidgets('shows "99+" when count > 99', (tester) async {
      await _pumpBadge(
        tester,
        source: NavBadgeSource.activities,
        count: 150,
      );

      expect(find.text('99+'), findsOneWidget);
      expect(find.text('150'), findsNothing);
    });

    testWidgets('shows "99" (not 99+) when count == 99', (tester) async {
      await _pumpBadge(
        tester,
        source: NavBadgeSource.activities,
        count: 99,
      );

      expect(find.text('99'), findsOneWidget);
      expect(find.text('99+'), findsNothing);
    });

    testWidgets('child widget is always rendered', (tester) async {
      await _pumpBadge(
        tester,
        source: NavBadgeSource.none,
        count: 0,
      );

      // The Icon child should always be present
      expect(find.byType(Icon), findsOneWidget);
    });
  });
}
