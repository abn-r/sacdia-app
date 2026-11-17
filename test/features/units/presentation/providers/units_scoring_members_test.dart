import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';
import 'package:sacdia_app/features/units/domain/entities/scoring_category.dart';
import 'package:sacdia_app/features/units/domain/entities/unit.dart';
import 'package:sacdia_app/features/units/domain/entities/unit_member.dart';
import 'package:sacdia_app/features/units/presentation/providers/units_providers.dart';

import '../../../../support/riverpod_test_support.dart';

class _Notifier extends UnitsNotifier {
  @override
  UnitsState build() => const UnitsState(
        units: [],
        categories: [
          ScoringCategory(
            scoringCategoryId: 1,
            name: 'Asistencia',
            maxPoints: 10,
            originLevel: 'LOCAL_FIELD',
            originId: 1,
          ),
        ],
      );
}

void main() {
  const unit = Unit(
    id: 7,
    name: 'Centinelas',
    type: 'Conquistadores',
    memberCount: 1,
    captainId: 'cap',
    secretaryId: 'sec',
    advisorId: 'adv',
    members: [UnitMember(id: 'm-1', name: 'Ana', surname: 'L')],
    serverScoringMembers: [
      UnitMember(
          id: 'cap', name: 'Cap', surname: 'C', role: UnitMemberRole.captain),
      UnitMember(
          id: 'sec', name: 'Sec', surname: 'S', role: UnitMemberRole.secretary),
      UnitMember(id: 'm-1', name: 'Ana', surname: 'L'),
    ],
  );

  test('selectUnit builds initial scores for captain and secretary', () async {
    final container = createTestContainer(overrides: [
      unitsNotifierProvider.overrideWith(_Notifier.new),
      clubContextProvider.overrideWith((ref) async => null),
    ]);
    container.listen(unitsNotifierProvider, (_, __) {});

    await container.read(unitsNotifierProvider.notifier).selectUnit(unit);
    final state = container.read(unitsNotifierProvider);

    expect(state.members.map((m) => m.id), ['cap', 'sec', 'm-1']);
    expect(state.pendingScores.keys, ['cap', 'sec', 'm-1']);
    expect(state.pendingScores['cap'], {1: 0});

    // "Set for all" also covers the leaders, and totals include them.
    final notifier = container.read(unitsNotifierProvider.notifier);
    notifier.setCategoryPointsForAllMembers(1, 5);
    final after = container.read(unitsNotifierProvider);
    expect(after.totalPendingForMember('cap'), 5);
    expect(after.totalPendingForMember('sec'), 5);
    expect(after.totalPendingForMember('m-1'), 5);
    // Plain management list is untouched.
    expect(after.selectedUnit?.members.map((m) => m.id), ['m-1']);
  });

  test('fallback list excludes counselors in the notifier too', () async {
    const old = Unit(
      id: 8,
      name: 'Viejo',
      type: 'Conquistadores',
      memberCount: 3,
      captainId: 'cap',
      advisorId: 'adv',
      members: [
        UnitMember(id: 'adv', name: 'Adv', surname: 'A'),
        UnitMember(id: 'cap', name: 'Cap', surname: 'C'),
        UnitMember(id: 'm-1', name: 'Ana', surname: 'L'),
      ],
    );
    final container = createTestContainer(overrides: [
      unitsNotifierProvider.overrideWith(_Notifier.new),
      clubContextProvider.overrideWith((ref) async => null),
    ]);
    container.listen(unitsNotifierProvider, (_, __) {});

    await container.read(unitsNotifierProvider.notifier).selectUnit(old);
    final state = container.read(unitsNotifierProvider);
    expect(state.members.map((m) => m.id), ['cap', 'm-1']);
    expect(state.pendingScores.containsKey('adv'), isFalse);
  });
}
