import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';
import '../../../../support/riverpod_test_support.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

Future<bool> _available(UserEntity? user) async {
  final container = createTestContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(user)),
    ],
  );
  await container.read(authNotifierProvider.future);
  return container.read(masterHonorsAvailableProvider);
}

void main() {
  group('masterHonorsAvailableProvider', () {
    test('an adult on their own account sees master honors', () async {
      expect(await _available(const UserEntity(id: 'adult')), isTrue);
    });

    test('a supervised teen does not (the server denies the route)', () async {
      const teen = UserEntity(
        id: 'teen',
        principal: PrincipalInfo(
          kind: PrincipalKind.supervisedUser,
          supervision: SupervisionInfo(status: SupervisionStatus.active),
        ),
      );
      expect(await _available(teen), isFalse);
    });

    test('a linked device does not', () async {
      const device = UserEntity(
        id: 'device',
        principal: PrincipalInfo(kind: PrincipalKind.linkedDevice),
      );
      expect(await _available(device), isFalse);
    });

    test('no session does not', () async {
      expect(await _available(null), isFalse);
    });
  });
}
