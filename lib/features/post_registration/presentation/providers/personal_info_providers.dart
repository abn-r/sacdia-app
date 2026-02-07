import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/personal_info_remote_data_source.dart';
import '../../data/models/emergency_contact_model.dart';
import '../../data/models/legal_representative_model.dart';
import '../../data/models/allergy_model.dart';
import '../../data/models/disease_model.dart';
import '../../data/models/relationship_type_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

/// Provider del data source de información personal
final personalInfoDataSourceProvider = Provider<PersonalInfoRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return PersonalInfoRemoteDataSourceImpl(
    dio: dio,
    secureStorage: const FlutterSecureStorage(),
  );
});

/// Estado del formulario de información personal
class PersonalInfoFormState {
  final String? gender;
  final DateTime? birthdate;
  final bool baptized;
  final DateTime? baptismDate;

  const PersonalInfoFormState({
    this.gender,
    this.birthdate,
    this.baptized = false,
    this.baptismDate,
  });

  PersonalInfoFormState copyWith({
    String? gender,
    DateTime? birthdate,
    bool? baptized,
    DateTime? baptismDate,
  }) {
    return PersonalInfoFormState(
      gender: gender ?? this.gender,
      birthdate: birthdate ?? this.birthdate,
      baptized: baptized ?? this.baptized,
      baptismDate: baptismDate ?? this.baptismDate,
    );
  }
}

/// Provider del estado del formulario de información personal
final personalInfoFormProvider = StateProvider<PersonalInfoFormState>((ref) {
  return const PersonalInfoFormState();
});

/// Provider de tipos de relación
final relationshipTypesProvider = FutureProvider<List<RelationshipTypeModel>>((ref) async {
  final dataSource = ref.watch(personalInfoDataSourceProvider);
  return await dataSource.getRelationshipTypes();
});

/// Provider de catálogo de alergias
final allergiesCatalogProvider = FutureProvider<List<AllergyModel>>((ref) async {
  final dataSource = ref.watch(personalInfoDataSourceProvider);
  return await dataSource.getAllergiesCatalog();
});

/// Provider de catálogo de enfermedades
final diseasesCatalogProvider = FutureProvider<List<DiseaseModel>>((ref) async {
  final dataSource = ref.watch(personalInfoDataSourceProvider);
  return await dataSource.getDiseasesCatalog();
});

/// Provider de alergias seleccionadas
final selectedAllergiesProvider = StateProvider<List<int>>((ref) => []);

/// Provider de enfermedades seleccionadas
final selectedDiseasesProvider = StateProvider<List<int>>((ref) => []);

/// Provider que verifica si se requiere representante legal
final legalRepresentativeRequiredProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.valueOrNull?.id;

  if (userId == null) return false;

  final dataSource = ref.watch(personalInfoDataSourceProvider);
  return await dataSource.checkLegalRepresentativeRequired(userId);
});

/// Notifier de contactos de emergencia
class EmergencyContactsNotifier extends AsyncNotifier<List<EmergencyContactModel>> {
  @override
  Future<List<EmergencyContactModel>> build() async {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.valueOrNull?.id;

    if (userId == null) return [];

    final dataSource = ref.watch(personalInfoDataSourceProvider);
    return await dataSource.getEmergencyContacts(userId);
  }

  /// Agrega un nuevo contacto de emergencia
  Future<void> addContact(EmergencyContactModel contact) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      // Verificar límite de contactos
      final currentContacts = await future;
      if (currentContacts.length >= 5) {
        throw Exception('Máximo 5 contactos de emergencia permitidos');
      }

      final dataSource = ref.read(personalInfoDataSourceProvider);
      await dataSource.addEmergencyContact(userId, contact);

      // Recargar la lista
      return await dataSource.getEmergencyContacts(userId);
    });
  }

  /// Actualiza un contacto de emergencia existente
  Future<void> updateContact(int contactId, EmergencyContactModel contact) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final dataSource = ref.read(personalInfoDataSourceProvider);
      await dataSource.updateEmergencyContact(contactId, contact);

      // Recargar la lista
      return await dataSource.getEmergencyContacts(userId);
    });
  }

  /// Elimina un contacto de emergencia
  Future<void> deleteContact(int contactId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final dataSource = ref.read(personalInfoDataSourceProvider);
      await dataSource.deleteEmergencyContact(contactId);

      // Recargar la lista
      return await dataSource.getEmergencyContacts(userId);
    });
  }

  /// Recarga la lista de contactos
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) return [];

      final dataSource = ref.read(personalInfoDataSourceProvider);
      return await dataSource.getEmergencyContacts(userId);
    });
  }
}

/// Provider de contactos de emergencia
final emergencyContactsProvider =
    AsyncNotifierProvider<EmergencyContactsNotifier, List<EmergencyContactModel>>(
  () => EmergencyContactsNotifier(),
);

/// Notifier de representante legal
class LegalRepresentativeNotifier extends AsyncNotifier<LegalRepresentativeModel?> {
  @override
  Future<LegalRepresentativeModel?> build() async {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.valueOrNull?.id;

    if (userId == null) return null;

    final dataSource = ref.watch(personalInfoDataSourceProvider);
    return await dataSource.getLegalRepresentative(userId);
  }

  /// Crea o actualiza el representante legal
  Future<void> saveRepresentative(LegalRepresentativeModel representative) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final dataSource = ref.read(personalInfoDataSourceProvider);
      final existing = await dataSource.getLegalRepresentative(userId);

      if (existing == null) {
        return await dataSource.createLegalRepresentative(userId, representative);
      } else {
        return await dataSource.updateLegalRepresentative(userId, representative);
      }
    });
  }
}

/// Provider de representante legal
final legalRepresentativeProvider =
    AsyncNotifierProvider<LegalRepresentativeNotifier, LegalRepresentativeModel?>(
  () => LegalRepresentativeNotifier(),
);

/// Provider que determina si se puede completar el paso 2
final canCompleteStep2Provider = Provider<bool>((ref) {
  // Verificar formulario personal
  final formState = ref.watch(personalInfoFormProvider);
  if (formState.gender == null || formState.birthdate == null) {
    return false;
  }

  if (formState.baptized && formState.baptismDate == null) {
    return false;
  }

  // Verificar contactos de emergencia (al menos 1)
  final contactsAsync = ref.watch(emergencyContactsProvider);
  final hasContacts = contactsAsync.maybeWhen(
    data: (contacts) => contacts.isNotEmpty,
    orElse: () => false,
  );

  if (!hasContacts) return false;

  // Verificar representante legal si es requerido
  final requiresRepAsync = ref.watch(legalRepresentativeRequiredProvider);
  final requiresRep = requiresRepAsync.maybeWhen(
    data: (required) => required,
    orElse: () => false,
  );

  if (requiresRep) {
    final repAsync = ref.watch(legalRepresentativeProvider);
    final hasRep = repAsync.maybeWhen(
      data: (rep) => rep != null,
      orElse: () => false,
    );

    if (!hasRep) return false;
  }

  return true;
});

/// Provider para guardar información personal
final savePersonalInfoProvider = Provider<Future<void> Function()>((ref) {
  return () async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.valueOrNull?.id;

    if (userId == null) throw Exception('Usuario no autenticado');

    final formState = ref.read(personalInfoFormProvider);
    final dataSource = ref.read(personalInfoDataSourceProvider);

    // Guardar información personal
    await dataSource.updatePersonalInfo(
      userId,
      gender: formState.gender,
      birthdate: formState.birthdate?.toIso8601String().split('T')[0],
      baptized: formState.baptized,
      baptismDate: formState.baptismDate?.toIso8601String().split('T')[0],
    );

    // Guardar alergias
    final selectedAllergies = ref.read(selectedAllergiesProvider);
    if (selectedAllergies.isNotEmpty) {
      await dataSource.saveUserAllergies(userId, selectedAllergies);
    }

    // Guardar enfermedades
    final selectedDiseases = ref.read(selectedDiseasesProvider);
    if (selectedDiseases.isNotEmpty) {
      await dataSource.saveUserDiseases(userId, selectedDiseases);
    }

    // Completar paso 2
    await dataSource.completeStep2(userId);
  };
});
