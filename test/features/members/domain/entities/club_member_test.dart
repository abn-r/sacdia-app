import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';

ClubMember _member(String? role) =>
    ClubMember(userId: 'u1', name: 'Test', clubRole: role);

void main() {
  group('ClubMember.isSectionBoard', () {
    test('is true for the seven board roles', () {
      for (final role in const [
        'director',
        'deputy-director',
        'secretary',
        'treasurer',
        'secretary-treasurer',
        'counselor',
        'instructor',
      ]) {
        expect(_member(role).isSectionBoard, isTrue, reason: role);
      }
    });

    test('tolerates case, underscores, spaces and padding', () {
      expect(_member('Deputy_Director').isSectionBoard, isTrue);
      expect(_member('SECRETARY_TREASURER').isSectionBoard, isTrue);
      expect(_member(' deputy director ').isSectionBoard, isTrue);
      expect(_member('Instructor').isSectionBoard, isTrue);
    });

    test('is false for member, unknown, empty and null', () {
      expect(_member('member').isSectionBoard, isFalse);
      expect(_member('miembro').isSectionBoard, isFalse);
      expect(_member('').isSectionBoard, isFalse);
      expect(_member(null).isSectionBoard, isFalse);
    });
  });
}
