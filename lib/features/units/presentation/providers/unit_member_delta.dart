import '../../domain/entities/unit.dart';
import '../../domain/entities/unit_member.dart';

class UnitMemberDelta {
  final List<String> userIdsToAdd;
  final List<UnitMember> membersToRemove;

  const UnitMemberDelta({
    required this.userIdsToAdd,
    required this.membersToRemove,
  });

  bool get isEmpty => userIdsToAdd.isEmpty && membersToRemove.isEmpty;
}

UnitMemberDelta computeUnitMemberDelta({
  required List<UnitMember> currentMembers,
  required List<String> desiredUserIds,
}) {
  final desired = desiredUserIds.toSet();
  final currentByUserId = {
    for (final member in currentMembers) member.id: member,
  };
  final current = currentByUserId.keys.toSet();

  return UnitMemberDelta(
    userIdsToAdd: desired.difference(current).toList(),
    membersToRemove: current
        .difference(desired)
        .map((userId) => currentByUserId[userId])
        .whereType<UnitMember>()
        .toList(),
  );
}

Unit? selectUnitForMemberDelta({
  required List<Unit> units,
  required Unit? selectedUnit,
  required int unitId,
}) {
  final selected = selectedUnit?.id == unitId ? selectedUnit : null;
  final listed = units.where((unit) => unit.id == unitId).firstOrNull;

  if (selected != null && selected.members.isNotEmpty) return selected;
  if (listed != null && listed.members.isNotEmpty) return listed;

  return selected ?? listed;
}
