import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async {
    return const UserEntity(id: 'user-123', email: 'ana@example.com');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('personal info preload', () {
    test('maps backend user snapshot into the step 2 form state', () {
      final snapshot = PersonalInfoSnapshot.fromJson({
        'gender': 'F',
        'birthday': '2013-04-10T00:00:00.000Z',
        'baptism': true,
        'baptism_date': '2024-01-20T00:00:00.000Z',
        'blood': 'O_POSITIVE',
      });

      final formState = PersonalInfoFormState.fromSnapshot(snapshot);

      expect(formState.gender, 'F');
      expect(formState.birthdate?.year, 2013);
      expect(formState.baptized, isTrue);
      expect(formState.baptismDate?.year, 2024);
      expect(formState.bloodType?.apiKey, 'O_POSITIVE');
    });
  });

  group('health none state', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists explicit none declarations per user and category', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      final initial = await container.read(healthNoneStateProvider.future);
      expect(initial.allergies, isFalse);

      await container.read(healthNoneStateProvider.notifier).setAllergies(true);

      final updated = container.read(healthNoneStateProvider).valueOrNull;
      expect(updated?.allergies, isTrue);
      expect(
        prefs.getBool('post_registration.health_none.user-123.allergies'),
        isTrue,
      );
    });
  });
}
