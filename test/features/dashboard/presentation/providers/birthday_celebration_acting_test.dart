import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/utils/birthday_utils.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/birthday_celebration_provider.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../support/riverpod_test_support.dart';

/// S6 (re-verify 2b): mientras se actúa por un menor, descartar el aviso de
/// cumpleaños no deja ninguna bandera en disco (FP-49).

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;
}

void main() {
  late SharedPreferences prefs;
  late DateTime birthday;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    birthday = DateTime(now.year - 10, now.month, now.day);
  });

  ProviderContainer build(String userId, ActingForSession session) {
    final container = createTestContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        actingForSessionProvider.overrideWithValue(session),
        authNotifierProvider.overrideWith(
          () => _FakeAuthNotifier(
            UserEntity(id: userId, name: userId, birthday: birthday),
          ),
        ),
      ],
    );
    return container;
  }

  Set<String> birthdayKeys() =>
      prefs.getKeys().where((k) => k.startsWith('sacdia:birthday:')).toSet();

  test('acting for a dependent: dismissing is in memory only, no disk flag',
      () async {
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1'));
    final container = build('ana-1', session);
    container.listen(birthdayCelebrationProvider, (_, __) {});
    await container.read(birthdayCelebrationProvider.future);

    await container
        .read(birthdayCelebrationProvider.notifier)
        .dismissForToday();

    expect(birthdayKeys(), isEmpty);
    expect(
      container
          .read(birthdayCelebrationProvider)
          .valueOrNull
          ?.dismissedForToday,
      isTrue,
      reason: 'the entry point is still dismissed for the session',
    );
  });

  test('control: the guardian own dismissal is still persisted', () async {
    final container = build('guardian-1', ActingForSession());
    container.listen(birthdayCelebrationProvider, (_, __) {});
    await container.read(birthdayCelebrationProvider.future);

    await container
        .read(birthdayCelebrationProvider.notifier)
        .dismissForToday();

    expect(
      birthdayKeys(),
      {birthdayDismissalKey(userId: 'guardian-1', birthday: birthday)},
    );
  });
}
