import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/personal_info_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(id: 'user-1');
}

class _Datasource implements PersonalInfoRemoteDataSource {
  _Datasource(this.contacts);

  List<EmergencyContactModel> contacts;
  Object? mutationError;
  int getCalls = 0;

  @override
  Future<List<EmergencyContactModel>> getEmergencyContacts(
    String userId, {
    cancelToken,
  }) async {
    getCalls++;
    return List.of(contacts);
  }

  @override
  Future<EmergencyContactModel> addEmergencyContact(
      String userId, EmergencyContactModel contact) async {
    if (mutationError != null) throw mutationError!;
    final saved = contact.copyWith(id: contacts.length + 100);
    contacts = [...contacts, saved];
    return saved;
  }

  @override
  Future<EmergencyContactModel> updateEmergencyContact(
      String userId, int contactId, EmergencyContactModel contact) async {
    if (mutationError != null) throw mutationError!;
    contacts = [
      for (final c in contacts) c.id == contactId ? contact : c,
    ];
    return contact;
  }

  @override
  Future<void> deleteEmergencyContact(String userId, int contactId) async {
    if (mutationError != null) throw mutationError!;
    contacts = contacts.where((c) => c.id != contactId).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

EmergencyContactModel _contact(int? id, String name) => EmergencyContactModel(
      id: id,
      name: name,
      phone: '5512345678',
      relationshipTypeId: 'rel-1',
    );

void main() {
  late _Datasource datasource;
  late ProviderContainer container;

  setUp(() async {
    datasource = _Datasource([_contact(1, 'Ana'), _contact(2, 'Luis')]);
    container = ProviderContainer(overrides: [
      authNotifierProvider.overrideWith(_FakeAuthNotifier.new),
      personalInfoDataSourceProvider.overrideWithValue(datasource),
    ]);
    addTearDown(container.dispose);
    // Mantiene vivo el autoDispose durante la prueba.
    container.listen(emergencyContactsProvider, (_, __) {});
    await container.read(emergencyContactsProvider.future);
  });

  List<String> names() => container
      .read(emergencyContactsProvider)
      .requireValue
      .map((c) => c.name)
      .toList();

  group('EmergencyContactsNotifier', () {
    test('addContact refreshes the list on success', () async {
      await container
          .read(emergencyContactsProvider.notifier)
          .addContact(_contact(null, 'Marta'));

      expect(names(), ['Ana', 'Luis', 'Marta']);
    });

    test('addContact rethrows and keeps the previous contacts on failure',
        () async {
      datasource.mutationError = Exception('boom');

      await expectLater(
        container
            .read(emergencyContactsProvider.notifier)
            .addContact(_contact(null, 'Marta')),
        throwsA(isA<Exception>()),
      );

      final state = container.read(emergencyContactsProvider);
      expect(state.hasError, isFalse);
      expect(state.isLoading, isFalse);
      expect(names(), ['Ana', 'Luis']);
    });

    test('addContact refuses a sixth contact and keeps the list', () async {
      datasource.contacts = [for (var i = 1; i <= 5; i++) _contact(i, 'C$i')];
      await container.read(emergencyContactsProvider.notifier).refresh();

      await expectLater(
        container
            .read(emergencyContactsProvider.notifier)
            .addContact(_contact(null, 'Extra')),
        throwsA(isA<Exception>()),
      );
      expect(names(), ['C1', 'C2', 'C3', 'C4', 'C5']);
    });

    test('updateContact refreshes on success and rethrows on failure',
        () async {
      final notifier = container.read(emergencyContactsProvider.notifier);
      await notifier.updateContact(1, _contact(1, 'Ana María'));
      expect(names(), ['Ana María', 'Luis']);

      datasource.mutationError = Exception('boom');
      await expectLater(
        notifier.updateContact(1, _contact(1, 'Otra')),
        throwsA(isA<Exception>()),
      );
      expect(container.read(emergencyContactsProvider).hasError, isFalse);
      expect(names(), ['Ana María', 'Luis']);
    });

    test('deleteContact refreshes on success and rethrows on failure',
        () async {
      final notifier = container.read(emergencyContactsProvider.notifier);
      datasource.mutationError = Exception('boom');
      await expectLater(
        notifier.deleteContact(1),
        throwsA(isA<Exception>()),
      );
      expect(container.read(emergencyContactsProvider).hasError, isFalse);
      expect(names(), ['Ana', 'Luis']);

      datasource.mutationError = null;
      await notifier.deleteContact(1);
      expect(names(), ['Luis']);
    });
  });
}
