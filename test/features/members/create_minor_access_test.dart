import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/members/presentation/utils/create_minor_access.dart';

UserEntity _user({
  List<String> permissions = const [],
  FamilyFeatures? features,
}) =>
    UserEntity(
      id: 'u-1',
      email: 'a@b.c',
      name: 'Laura',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(effectivePermissions: permissions),
      familyFeatures: features,
    );

void main() {
  const on = FamilyFeatures(directorCreateMinor: true);

  test('needs BOTH dependents:create and the director_create_minor flag', () {
    expect(
        canRegisterMinor(
            _user(permissions: ['dependents:create'], features: on)),
        isTrue);
  });

  test('no permission: hidden even with the flag on', () {
    expect(
        canRegisterMinor(
            _user(permissions: ['club_members:approve'], features: on)),
        isFalse);
  });

  test('flag off, absent or unknown: hidden even with the permission', () {
    const off = FamilyFeatures();
    expect(
        canRegisterMinor(
            _user(permissions: ['dependents:create'], features: off)),
        isFalse);
    expect(
        canRegisterMinor(_user(permissions: ['dependents:create'])), isFalse);
  });

  test('no user, no authorization: hidden', () {
    expect(canRegisterMinor(null), isFalse);
    expect(
      canRegisterMinor(const UserEntity(id: 'u', familyFeatures: on)),
      isFalse,
    );
  });
}
