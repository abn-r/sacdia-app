import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/features/members/presentation/providers/members_providers.dart';

ClubContext _ctx(String? roleName) =>
    ClubContext(clubId: 1, sectionId: 2, roleName: roleName);

void main() {
  group('ClubContext.isInvestitureBoard', () {
    test('is true for director, secretary and secretary-treasurer', () {
      expect(_ctx('secretary-treasurer').isInvestitureBoard, isTrue);
      expect(_ctx('director').isInvestitureBoard, isTrue);
      expect(_ctx('secretary').isInvestitureBoard, isTrue);
    });

    test('is case and whitespace insensitive', () {
      expect(_ctx('  Secretary-Treasurer ').isInvestitureBoard, isTrue);
    });

    test('is false for deputy-director, counselor, treasurer and member', () {
      expect(_ctx('deputy-director').isInvestitureBoard, isFalse);
      expect(_ctx('counselor').isInvestitureBoard, isFalse);
      expect(_ctx('treasurer').isInvestitureBoard, isFalse);
      expect(_ctx('member').isInvestitureBoard, isFalse);
    });

    test('is false when the role is unknown', () {
      expect(_ctx(null).isInvestitureBoard, isFalse);
    });
  });

  test('ClubRoleNames.investitureBoard lists the three board roles', () {
    expect(
      ClubRoleNames.investitureBoard,
      [
        ClubRoleNames.director,
        ClubRoleNames.secretary,
        ClubRoleNames.secretaryTreasurer,
      ],
    );
  });
}
