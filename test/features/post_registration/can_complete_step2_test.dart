import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import '../../support/riverpod_test_support.dart';

class _FakeContacts extends EmergencyContactsNotifier {
  _FakeContacts(this._contacts);
  final List<EmergencyContactModel> _contacts;

  @override
  Future<List<EmergencyContactModel>> build() async => _contacts;
}

const _contact = EmergencyContactModel(
  name: 'Contacto',
  phone: '5512345678',
  relationshipTypeId: 'rel-1',
);

ProviderContainer _container({
  PersonalInfoFormState? form,
  List<EmergencyContactModel> contacts = const [_contact],
}) {
  final container = createTestContainer(
    overrides: [
      personalInfoFormProvider.overrideWith(
        (ref) =>
            form ??
            PersonalInfoFormState(
              gender: 'M',
              birthdate: DateTime(2012, 1, 1),
            ),
      ),
      emergencyContactsProvider.overrideWith(() => _FakeContacts(contacts)),
    ],
  );
  return container;
}

Future<void> _settle(ProviderContainer c) async {
  // Mantiene vivos los providers autoDispose y espera a que resuelvan.
  c.listen(canCompleteStep2Provider, (_, __) {});
  await c.read(emergencyContactsProvider.future);
}

void main() {
  // Phase 2 (family profiles): the legal representative no longer gates step 2.
  // A minor now registers through a guardian, so a young birthdate must not
  // block the step by itself.
  test('is true for a young birthdate with a contact (no legal-rep gate)',
      () async {
    final c = _container();
    await _settle(c);

    expect(c.read(canCompleteStep2Provider), isTrue);
  });

  test('is false without an emergency contact', () async {
    final c = _container(contacts: const []);
    await _settle(c);

    expect(c.read(canCompleteStep2Provider), isFalse);
  });

  test('is false without gender or birthdate', () async {
    final c = _container(form: const PersonalInfoFormState());
    await _settle(c);

    expect(c.read(canCompleteStep2Provider), isFalse);
  });

  test('is false when baptized without a baptism date', () async {
    final c = _container(
      form: PersonalInfoFormState(
        gender: 'F',
        birthdate: DateTime(1990, 5, 5),
        baptized: true,
      ),
    );
    await _settle(c);

    expect(c.read(canCompleteStep2Provider), isFalse);
  });
}
