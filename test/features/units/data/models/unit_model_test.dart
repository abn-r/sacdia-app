import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/units/data/models/unit_model.dart';

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
}
