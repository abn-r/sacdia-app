import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/club_role_names.dart';
import 'package:sacdia_app/core/authorization/generated/role_names.dart';

void main() {
  group('normalizeClubRoleName', () {
    test('lowercases and turns underscores into hyphens', () {
      expect(
        normalizeClubRoleName('Secretary_Treasurer'),
        'secretary-treasurer',
      );
    });

    test('trims and turns inner spaces into hyphens', () {
      expect(normalizeClubRoleName(' deputy director '), 'deputy-director');
    });

    test('collapses runs of separators', () {
      expect(
        normalizeClubRoleName('secretary__treasurer'),
        'secretary-treasurer',
      );
      expect(normalizeClubRoleName('deputy _ director'), 'deputy-director');
    });

    test('null and empty yield empty string', () {
      expect(normalizeClubRoleName(null), '');
      expect(normalizeClubRoleName(''), '');
      expect(normalizeClubRoleName('   '), '');
    });
  });

  group('canonicalClubRoleName', () {
    test('maps Spanish aliases to canonical names', () {
      expect(
          canonicalClubRoleName('Subdirector'), ClubRoleNames.deputyDirector);
      expect(canonicalClubRoleName('secretario'), ClubRoleNames.secretary);
      expect(canonicalClubRoleName('Tesorero'), ClubRoleNames.treasurer);
      expect(canonicalClubRoleName('consejero'), ClubRoleNames.counselor);
      expect(canonicalClubRoleName('miembro'), ClubRoleNames.member);
      expect(
        canonicalClubRoleName('Secretario_Tesorero'),
        ClubRoleNames.secretaryTreasurer,
      );
    });

    test('keeps canonical names and unknown values normalized', () {
      expect(canonicalClubRoleName('deputy-director'), 'deputy-director');
      expect(
          canonicalClubRoleName('Secretary Treasurer'), 'secretary-treasurer');
      expect(canonicalClubRoleName('Foo Bar'), 'foo-bar');
      expect(canonicalClubRoleName(null), '');
    });
  });

  test('alias targets and keys are valid', () {
    expect(
      kClubRoleSpanishAliases.values.toSet().difference(kClubRoleNames.toSet()),
      isEmpty,
    );
    for (final k in kClubRoleSpanishAliases.keys) {
      expect(normalizeClubRoleName(k), k);
    }
  });
}
