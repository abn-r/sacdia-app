import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/persona/nav_slot.dart';

void main() {
  group('NavSlot — T-03 Equatable equality and hashCode', () {
    const slotA = NavSlot(
      icon: HugeIcons.strokeRoundedHome01,
      labelKey: 'nav.dashboard',
      branchIndex: 0,
      route: RouteNames.homeDashboard,
      badgeSource: NavBadgeSource.none,
    );

    const slotB = NavSlot(
      icon: HugeIcons.strokeRoundedHome01,
      labelKey: 'nav.dashboard',
      branchIndex: 0,
      route: RouteNames.homeDashboard,
      badgeSource: NavBadgeSource.none,
    );

    const slotC = NavSlot(
      icon: HugeIcons.strokeRoundedUser,
      labelKey: 'nav.profile',
      branchIndex: 3,
      route: RouteNames.homeProfile,
    );

    test('two identical NavSlots are equal', () {
      expect(slotA, equals(slotB));
    });

    test('two different NavSlots are not equal', () {
      expect(slotA, isNot(equals(slotC)));
    });

    test('identical slots have the same hashCode', () {
      expect(slotA.hashCode, equals(slotB.hashCode));
    });

    test('different slots have different hashCodes (very likely)', () {
      // Not guaranteed by contract but highly expected.
      expect(slotA.hashCode, isNot(equals(slotC.hashCode)));
    });
  });

  group('NavBadgeSource — T-02 enum values', () {
    test('has exactly 6 values', () {
      expect(NavBadgeSource.values.length, 6);
    });

    test('contains expected values', () {
      expect(
          NavBadgeSource.values,
          containsAll([
            NavBadgeSource.activities,
            NavBadgeSource.unit,
            NavBadgeSource.members,
            NavBadgeSource.finances,
            NavBadgeSource.hub,
            NavBadgeSource.none,
          ]));
    });
  });
}
