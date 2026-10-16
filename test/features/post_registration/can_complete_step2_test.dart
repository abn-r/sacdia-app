import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/legal_representative_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';

class _FakeContacts extends EmergencyContactsNotifier {
  @override
  Future<List<EmergencyContactModel>> build() async => [
        const EmergencyContactModel(
          name: 'Contacto',
          phone: '5512345678',
          relationshipTypeId: 'rel-1',
        ),
      ];
}

class _FakeRep extends LegalRepresentativeNotifier {
  _FakeRep(this._rep);
  final LegalRepresentativeModel? _rep;

  @override
  Future<LegalRepresentativeModel?> build() async => _rep;
}

const _rep = LegalRepresentativeModel(
  name: 'Ana',
  paternalSurname: 'Lopez',
  maternalSurname: '',
  phone: '5512345678',
  relationshipTypeId: 'rel-1',
);

ProviderContainer _container({
  required Future<bool> Function(Ref) check,
  LegalRepresentativeModel? rep,
}) {
  final container = ProviderContainer(
    overrides: [
      personalInfoFormProvider.overrideWith(
        (ref) => PersonalInfoFormState(
          gender: 'M',
          birthdate: DateTime(2012, 1, 1),
        ),
      ),
      emergencyContactsProvider.overrideWith(_FakeContacts.new),
      legalRepresentativeProvider.overrideWith(() => _FakeRep(rep)),
      legalRepresentativeRequiredProvider.overrideWith((ref) => check(ref)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<void> _settle(ProviderContainer c) async {
  // Mantiene vivos los providers autoDispose y espera a que resuelvan.
  c.listen(canCompleteStep2Provider, (_, __) {});
  await c.read(emergencyContactsProvider.future);
  await c.read(legalRepresentativeProvider.future);
}

void main() {
  test('is false while the required check is loading (fail-closed)', () async {
    final completer = Completer<bool>();
    final c = _container(check: (_) => completer.future);
    await _settle(c);

    expect(c.read(legalRepresentativeRequiredProvider).isLoading, isTrue);
    expect(c.read(canCompleteStep2Provider), isFalse);
  });

  test('is false when the required check failed (fail-closed)', () async {
    final c = _container(check: (_) async => throw Exception('boom'));
    await _settle(c);
    await expectLater(
      c.read(legalRepresentativeRequiredProvider.future),
      throwsException,
    );

    expect(c.read(legalRepresentativeRequiredProvider).hasError, isTrue);
    expect(c.read(canCompleteStep2Provider), isFalse);
  });

  test('is false for a minor without representative', () async {
    final c = _container(check: (_) async => true);
    await _settle(c);
    await c.read(legalRepresentativeRequiredProvider.future);

    expect(c.read(canCompleteStep2Provider), isFalse);
  });

  test('is true for a minor with a saved representative', () async {
    final c = _container(check: (_) async => true, rep: _rep);
    await _settle(c);
    await c.read(legalRepresentativeRequiredProvider.future);

    expect(c.read(canCompleteStep2Provider), isTrue);
  });

  test('is true for a non-minor without representative', () async {
    final c = _container(check: (_) async => false);
    await _settle(c);
    await c.read(legalRepresentativeRequiredProvider.future);

    expect(c.read(canCompleteStep2Provider), isTrue);
  });
}
