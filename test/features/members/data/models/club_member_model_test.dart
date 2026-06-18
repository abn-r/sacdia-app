import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/data/models/club_member_model.dart';

void main() {
  group('ClubMemberModel.fromJson', () {
    test('parses backend current_class class_id projection', () {
      final member = ClubMemberModel.fromJson({
        'assignment_id': 'assignment-1',
        'user_id': 'user-1',
        'user': {
          'user_id': 'user-1',
          'name': 'Cley Rey',
          'paternal_last_name': 'Ramírez',
        },
        'current_class': {
          'class_id': 6,
          'name': 'Guía',
          'enrollment_id': 55,
          'ecclesiastical_year_id': 2026,
        },
        'is_enrolled': true,
      });

      expect(member.currentClass, 'Guía');
      expect(member.currentClassId, 6);
    });

    test('parses flat current_class_name/current_class_id fallback', () {
      final member = ClubMemberModel.fromJson({
        'user_id': 'user-2',
        'name': 'Ana',
        'current_class_name': 'Amigo',
        'current_class_id': '1',
      });

      expect(member.currentClass, 'Amigo');
      expect(member.currentClassId, 1);
    });
  });
}
