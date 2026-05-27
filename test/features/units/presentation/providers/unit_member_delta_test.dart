import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/domain/entities/unit_member.dart';
import 'package:sacdia_app/features/units/presentation/providers/unit_member_delta.dart';

void main() {
  test('computes members to add and remove for edit reconciliation', () {
    final current = [
      const UnitMember(unitMemberId: 10, id: 'keep', name: 'Kee', surname: 'P'),
      const UnitMember(
          unitMemberId: 11, id: 'remove', name: 'Rem', surname: 'P'),
    ];

    final delta = computeUnitMemberDelta(
      currentMembers: current,
      desiredUserIds: ['keep', 'add'],
    );

    expect(delta.userIdsToAdd, ['add']);
    expect(delta.membersToRemove.map((m) => m.unitMemberId), [11]);
  });

  test('prefers selected unit detail over stale list unit for reconciliation',
      () {
    const staleListUnit = Unit(
      id: 7,
      name: 'Falcon',
      type: 'Conquistadores',
      memberCount: 0,
      members: [],
    );
    const detailedSelectedUnit = Unit(
      id: 7,
      name: 'Falcon',
      type: 'Conquistadores',
      memberCount: 1,
      members: [
        UnitMember(unitMemberId: 21, id: 'existing', name: 'Ex', surname: 'P'),
      ],
    );

    final unit = selectUnitForMemberDelta(
      units: [staleListUnit],
      selectedUnit: detailedSelectedUnit,
      unitId: 7,
    );

    expect(unit?.members.map((m) => m.unitMemberId), [21]);
  });
}
