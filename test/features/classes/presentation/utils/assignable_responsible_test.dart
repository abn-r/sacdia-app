import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/presentation/utils/assignable_responsible.dart';
import 'package:sacdia_app/features/members/domain/entities/club_member.dart';

ClubMember _member(String? role, {bool eligible = true}) => ClubMember(
      userId: 'u1',
      name: 'Test',
      clubRole: role,
      classCounselorEligible: eligible,
    );

void main() {
  group('isAssignableResponsible', () {
    test('accepts counselor and secretary, canonical and Spanish', () {
      for (final role in const [
        'counselor',
        'consejero',
        'secretary',
        'secretario',
        'Counselor',
        ' SECRETARIO ',
      ]) {
        expect(isAssignableResponsible(_member(role)), isTrue, reason: role);
      }
    });

    test('rejects other roles and null', () {
      for (final role in const [
        'director',
        'deputy-director',
        'treasurer',
        'secretary-treasurer',
        'secretario-tesorero',
        'member',
        'instructor',
        '',
      ]) {
        expect(isAssignableResponsible(_member(role)), isFalse, reason: role);
      }
      expect(isAssignableResponsible(_member(null)), isFalse);
    });

    test('rejects ineligible members even with a valid role', () {
      expect(isAssignableResponsible(_member('counselor', eligible: false)),
          isFalse);
    });
  });
}
