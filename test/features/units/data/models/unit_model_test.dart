import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/units/data/models/unit_model.dart';
import 'package:sacdia_app/features/units/domain/entities/unit_member.dart';

void main() {
  test('parses club local field and unit member ids from backend payload', () {
    final unit = UnitModel.fromJson({
      'unit_id': 7,
      'name': 'Unidad Águilas',
      'club_type_id': 2,
      'club_types': {'club_type_id': 2, 'name': 'Conquistadores'},
      'club_section_id': 10,
      'club_sections': {
        'club_section_id': 10,
        'clubs': {'local_field_id': 55},
      },
      'unit_members': [
        {
          'unit_member_id': 99,
          'user_id': 'user-1',
          'users': {'name': 'Ada', 'paternal_last_name': 'Lovelace'},
        }
      ],
    });

    expect(unit.localFieldId, 55);
    expect(unit.members.single.unitMemberId, 99);
  });

  test('keeps unit member id null when backend omits membership id', () {
    final unit = UnitModel.fromJson({
      'unit_id': 7,
      'name': 'Unidad Águilas',
      'club_types': {'club_type_id': 2, 'name': 'Conquistadores'},
      'unit_members': [
        {
          'user_id': 'user-1',
          'users': {'name': 'Ada', 'paternal_last_name': 'Lovelace'},
        }
      ],
    });

    expect(unit.members.single.unitMemberId, isNull);
  });

  group('scoring members', () {
    Map<String, dynamic> member(String id, String name) => {
          'unit_member_id': id.hashCode,
          'user_id': id,
          'users': {'name': name, 'paternal_last_name': 'X'},
        };

    test('parses scoring_members with roles when present', () {
      final unit = UnitModel.fromJson({
        'unit_id': 7,
        'name': 'U',
        'unit_members': [member('m-1', 'Ana')],
        'scoring_members': [
          {
            'user_id': 'cap',
            'name': 'Cap',
            'paternal_last_name': 'Uno',
            'maternal_last_name': 'Dos',
            'user_image': 'http://img',
            'unit_role': 'captain',
          },
          {'user_id': 'sec', 'name': 'Sec', 'unit_role': 'secretary'},
          {'user_id': 'm-1', 'name': 'Ana', 'unit_role': 'member'},
        ],
      });

      expect(unit.hasServerScoringMembers, isTrue);
      final list = unit.scoringMembers;
      expect(list.map((m) => m.id), ['cap', 'sec', 'm-1']);
      expect(list.map((m) => m.role), [
        UnitMemberRole.captain,
        UnitMemberRole.secretary,
        UnitMemberRole.member,
      ]);
      expect(list.first.fullName, 'Cap Uno Dos');
      expect(list.first.avatar, 'http://img');
      // La gestión de miembros sigue usando solo unit_members.
      expect(unit.members.map((m) => m.id), ['m-1']);
    });

    test('fallback without scoring_members keeps members, drops counselors',
        () {
      final unit = UnitModel.fromJson({
        'unit_id': 7,
        'name': 'U',
        'captain_id': 'cap',
        'secretary_id': 'sec',
        'advisor_id': 'adv',
        'substitute_advisor_id': 'sub',
        'unit_members': [
          member('m-1', 'Ana'),
          member('sec', 'Sec'),
          member('adv', 'Adv'),
          member('cap', 'Cap'),
          member('sub', 'Sub'),
          member('m-1', 'Ana'),
        ],
      });

      expect(unit.hasServerScoringMembers, isFalse);
      final list = unit.scoringMembers;
      expect(list.map((m) => m.id), ['cap', 'sec', 'm-1']);
      expect(list.map((m) => m.role), [
        UnitMemberRole.captain,
        UnitMemberRole.secretary,
        UnitMemberRole.member,
      ]);
    });

    test('fallback does not invent captain/secretary absent from members', () {
      final unit = UnitModel.fromJson({
        'unit_id': 7,
        'name': 'U',
        'captain_id': 'cap',
        'unit_members': [member('m-1', 'Ana')],
      });
      expect(unit.scoringMembers.map((m) => m.id), ['m-1']);
    });
  });
}
