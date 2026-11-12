import 'package:dartz/dartz.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/preferred_section_store.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_notifier_test_support.dart';

const _aventureros = AuthorizationGrant(
  assignmentId: 'a-163',
  roleName: 'director',
  clubId: 1,
  sectionId: 163,
  clubName: 'Estella',
  clubTypeName: 'Aventureros',
  status: 'active',
);

const _guias = AuthorizationGrant(
  assignmentId: 'a-164',
  roleName: 'member',
  clubId: 1,
  sectionId: 164,
  clubName: 'Estella',
  clubTypeName: 'Guías Mayores',
  status: 'active',
);

/// Servidor falso: `/auth/me` devuelve [active] como asignación activa y
/// `PATCH /auth/me/context` la cambia. [resetTo] simula el respaldo del
/// servidor (la primera operativa) tras un reinicio.
class _ServerRepo extends FakeAuthRepository {
  _ServerRepo({
    required this.userId,
    required this.active,
    this.assignments = const [_aventureros, _guias],
  });

  final String userId;
  final List<AuthorizationGrant> assignments;
  String? active;
  bool failSwitch = false;
  final switchCalls = <String>[];

  @override
  Future<bool> hasLocalToken() async => true;

  @override
  Future<Either<Failure, UserEntity?>> getCurrentUser() async => Right(
        UserEntity(
          id: userId,
          email: '$userId@example.com',
          postRegisterComplete: true,
          authorization: AuthorizationSnapshot(
            activeAssignmentId: active,
            clubAssignments: assignments,
          ),
        ),
      );

  @override
  Future<Either<Failure, void>> switchContext(String assignmentId) async {
    switchCalls.add(assignmentId);
    if (failSwitch) return const Left(NetworkFailure(message: 'offline'));
    active = assignmentId;
    return const Right(null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<ProviderContainer> boot(_ServerRepo repo) async {
    final container = await buildAuthContainer(repo: repo, prefs: prefs);
    await container.read(authNotifierProvider.future);
    return container;
  }

  String? activeOf(ProviderContainer c) =>
      c.read(authNotifierProvider).value?.authorization?.activeAssignmentId;

  group('restart keeps the selection', () {
    test('switching persists it and a restart reasserts it over the default',
        () async {
      final first = _ServerRepo(userId: 'u1', active: 'a-164');
      final c1 = await boot(first);
      expect(activeOf(c1), 'a-164');

      expect(
        await c1.read(authNotifierProvider.notifier).switchContext('a-163'),
        isTrue,
      );
      expect(activeOf(c1), 'a-163');
      expect(prefs.getString(PreferredSectionStore.keyFor('u1')), 'a-163');

      // Reinicio: el servidor vuelve a su respaldo (Guías Mayores).
      final second = _ServerRepo(userId: 'u1', active: 'a-164');
      final c2 = await boot(second);

      expect(second.switchCalls, ['a-163']);
      expect(activeOf(c2), 'a-163');
    });

    test('no extra PATCH when the server already agrees', () async {
      await PreferredSectionStore(prefs).write('u1', 'a-163');
      final repo = _ServerRepo(userId: 'u1', active: 'a-163');
      final c = await boot(repo);

      expect(repo.switchCalls, isEmpty);
      expect(activeOf(c), 'a-163');
    });

    test('first launch stores what the server picked', () async {
      final repo = _ServerRepo(userId: 'u1', active: 'a-164');
      await boot(repo);

      expect(repo.switchCalls, isEmpty);
      expect(prefs.getString(PreferredSectionStore.keyFor('u1')), 'a-164');
    });

    test('a failed reassert keeps the stored choice for the next try',
        () async {
      await PreferredSectionStore(prefs).write('u1', 'a-163');
      final repo = _ServerRepo(userId: 'u1', active: 'a-164')
        ..failSwitch = true;
      final c = await boot(repo);

      expect(repo.switchCalls, ['a-163']);
      expect(activeOf(c), 'a-164');
      expect(prefs.getString(PreferredSectionStore.keyFor('u1')), 'a-163');
    });
  });

  group('invalid stored selection falls back to the server', () {
    test('assignment no longer in the grants', () async {
      await PreferredSectionStore(prefs).write('u1', 'a-gone');
      final repo = _ServerRepo(userId: 'u1', active: 'a-164');
      final c = await boot(repo);

      expect(repo.switchCalls, isEmpty);
      expect(activeOf(c), 'a-164');
      expect(prefs.getString(PreferredSectionStore.keyFor('u1')), 'a-164');
    });

    test('assignment ended or expired is not reasserted', () async {
      await PreferredSectionStore(prefs).write('u1', 'a-163');
      const ended = AuthorizationGrant(
        assignmentId: 'a-163',
        roleName: 'director',
        clubId: 1,
        sectionId: 163,
        clubTypeName: 'Aventureros',
        status: 'expired',
      );
      final repo = _ServerRepo(
        userId: 'u1',
        active: 'a-164',
        assignments: const [ended, _guias],
      );
      final c = await boot(repo);

      expect(repo.switchCalls, isEmpty);
      expect(activeOf(c), 'a-164');
      expect(prefs.getString(PreferredSectionStore.keyFor('u1')), 'a-164');
    });
  });

  group('per-user isolation', () {
    test('another user\'s choice never applies', () async {
      await PreferredSectionStore(prefs).write('u2', 'a-163');
      final repo = _ServerRepo(userId: 'u1', active: 'a-164');
      final c = await boot(repo);

      expect(repo.switchCalls, isEmpty);
      expect(activeOf(c), 'a-164');
      // Lo de u2 queda intacto y u1 guarda lo suyo.
      expect(prefs.getString(PreferredSectionStore.keyFor('u2')), 'a-163');
      expect(prefs.getString(PreferredSectionStore.keyFor('u1')), 'a-164');
    });

    test('two accounts on one device keep their own selection', () async {
      final store = PreferredSectionStore(prefs);
      await store.write('u1', 'a-163');
      await store.write('u2', 'a-164');

      expect(store.read('u1'), 'a-163');
      expect(store.read('u2'), 'a-164');
      await store.clear('u1');
      expect(store.read('u1'), isNull);
      expect(store.read('u2'), 'a-164');
    });
  });

  group('pickPreferredAssignmentId', () {
    const auth = AuthorizationSnapshot(
      activeAssignmentId: 'a-164',
      clubAssignments: [_aventureros, _guias],
    );

    test('returns the stored id when valid and different', () {
      expect(
        pickPreferredAssignmentId(authorization: auth, stored: 'a-163'),
        'a-163',
      );
    });

    test('null when absent, equal to the active one, unknown or no snapshot',
        () {
      expect(
          pickPreferredAssignmentId(authorization: auth, stored: null), isNull);
      expect(pickPreferredAssignmentId(authorization: auth, stored: 'a-164'),
          isNull);
      expect(pickPreferredAssignmentId(authorization: auth, stored: 'zzz'),
          isNull);
      expect(pickPreferredAssignmentId(authorization: null, stored: 'a-163'),
          isNull);
    });
  });
}
