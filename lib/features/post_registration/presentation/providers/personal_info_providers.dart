import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/datasources/personal_info_remote_data_source.dart';
import '../../data/models/emergency_contact_model.dart';
import '../../data/models/legal_representative_model.dart';
import '../../data/models/allergy_model.dart';
import '../../data/models/disease_model.dart';
import '../../data/models/relationship_type_model.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../core/utils/app_logger.dart';

/// Provider del data source de información personal
final personalInfoDataSourceProvider =
    Provider<PersonalInfoRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  final baseUrl = ref.watch(apiBaseUrlProvider);
  return PersonalInfoRemoteDataSourceImpl(
    dio: dio,
    baseUrl: baseUrl,
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
final relationshipTypesProvider =
    FutureProvider<List<RelationshipTypeModel>>((ref) async {
  final dataSource = ref.watch(personalInfoDataSourceProvider);
  return await dataSource.getRelationshipTypes();
});

/// Provider de catálogo de alergias
final allergiesCatalogProvider =
    FutureProvider<List<AllergyModel>>((ref) async {
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

/// Notifier de alergias del usuario (pre-cargadas desde la API)
class UserAllergiesNotifier extends AsyncNotifier<List<AllergyModel>> {
  @override
  Future<List<AllergyModel>> build() async {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.valueOrNull?.id;

    if (userId == null) return [];

    final dataSource = ref.watch(personalInfoDataSourceProvider);
    final userAllergies = await dataSource.getUserAllergies(userId);

    final ids = userAllergies.map((a) => a.id).toList();
    ref.read(selectedAllergiesProvider.notifier).state = ids;

    return userAllergies;
  }

  /// Elimina una alergia del usuario (soft-delete)
  Future<void> deleteAllergy(int allergyId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final dataSource = ref.read(personalInfoDataSourceProvider);
      await dataSource.deleteUserAllergy(userId, allergyId);

      final currentIds = ref.read(selectedAllergiesProvider);
      ref.read(selectedAllergiesProvider.notifier).state =
          currentIds.where((id) => id != allergyId).toList();

      return await dataSource.getUserAllergies(userId);
    });
  }

  /// Recarga la lista de alergias del usuario
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) return [];

      final dataSource = ref.read(personalInfoDataSourceProvider);
      return await dataSource.getUserAllergies(userId);
    });
  }
}

/// Provider de alergias del usuario (con pre-carga)
final userAllergiesProvider =
    AsyncNotifierProvider<UserAllergiesNotifier, List<AllergyModel>>(
  () => UserAllergiesNotifier(),
);

/// Notifier de enfermedades del usuario (pre-cargadas desde la API)
class UserDiseasesNotifier extends AsyncNotifier<List<DiseaseModel>> {
  @override
  Future<List<DiseaseModel>> build() async {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.valueOrNull?.id;

    if (userId == null) return [];

    final dataSource = ref.watch(personalInfoDataSourceProvider);
    final userDiseases = await dataSource.getUserDiseases(userId);

    final ids = userDiseases.map((d) => d.id).toList();
    ref.read(selectedDiseasesProvider.notifier).state = ids;

    return userDiseases;
  }

  /// Elimina una enfermedad del usuario (soft-delete)
  Future<void> deleteDisease(int diseaseId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final dataSource = ref.read(personalInfoDataSourceProvider);
      await dataSource.deleteUserDisease(userId, diseaseId);

      final currentIds = ref.read(selectedDiseasesProvider);
      ref.read(selectedDiseasesProvider.notifier).state =
          currentIds.where((id) => id != diseaseId).toList();

      return await dataSource.getUserDiseases(userId);
    });
  }

  /// Recarga la lista de enfermedades del usuario
  Future<void> refresh() async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) return [];

      final dataSource = ref.read(personalInfoDataSourceProvider);
      return await dataSource.getUserDiseases(userId);
    });
  }
}

/// Provider de enfermedades del usuario (con pre-carga)
final userDiseasesProvider =
    AsyncNotifierProvider<UserDiseasesNotifier, List<DiseaseModel>>(
  () => UserDiseasesNotifier(),
);

/// Provider que verifica si se requiere representante legal
final legalRepresentativeRequiredProvider = FutureProvider<bool>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  final userId = authState.valueOrNull?.id;

  if (userId == null) return false;

  final dataSource = ref.watch(personalInfoDataSourceProvider);
  return await dataSource.checkLegalRepresentativeRequired(userId);
});

/// Notifier de contactos de emergencia
class EmergencyContactsNotifier
    extends AsyncNotifier<List<EmergencyContactModel>> {
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
    final currentContacts = state.valueOrNull ?? [];

    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      if (currentContacts.length >= 5) {
        throw Exception('Máximo 5 contactos de emergencia permitidos');
      }

      final dataSource = ref.read(personalInfoDataSourceProvider);
      await dataSource.addEmergencyContact(userId, contact);

      return await dataSource.getEmergencyContacts(userId);
    });
  }

  /// Actualiza un contacto de emergencia existente
  Future<void> updateContact(
      int contactId, EmergencyContactModel contact) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final dataSource = ref.read(personalInfoDataSourceProvider);
      await dataSource.updateEmergencyContact(userId, contactId, contact);

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
      await dataSource.deleteEmergencyContact(userId, contactId);

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
final emergencyContactsProvider = AsyncNotifierProvider<
    EmergencyContactsNotifier, List<EmergencyContactModel>>(
  () => EmergencyContactsNotifier(),
);

/// Notifier de representante legal
class LegalRepresentativeNotifier
    extends AsyncNotifier<LegalRepresentativeModel?> {
  @override
  Future<LegalRepresentativeModel?> build() async {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.valueOrNull?.id;

    if (userId == null) return null;

    final dataSource = ref.watch(personalInfoDataSourceProvider);
    return await dataSource.getLegalRepresentative(userId);
  }

  /// Crea o actualiza el representante legal
  Future<void> saveRepresentative(
      LegalRepresentativeModel representative) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final dataSource = ref.read(personalInfoDataSourceProvider);
      final existing = await dataSource.getLegalRepresentative(userId);

      if (existing == null) {
        return await dataSource.createLegalRepresentative(
            userId, representative);
      } else {
        return await dataSource.updateLegalRepresentative(
            userId, representative);
      }
    });
  }
}

/// Provider de representante legal
final legalRepresentativeProvider = AsyncNotifierProvider<
    LegalRepresentativeNotifier, LegalRepresentativeModel?>(
  () => LegalRepresentativeNotifier(),
);

/// Provider que determina si se puede completar el paso 2
final canCompleteStep2Provider = Provider<bool>((ref) {
  final formState = ref.watch(personalInfoFormProvider);
  if (formState.gender == null || formState.birthdate == null) {
    return false;
  }

  if (formState.baptized && formState.baptismDate == null) {
    return false;
  }

  final contactsAsync = ref.watch(emergencyContactsProvider);
  final hasContacts = contactsAsync.maybeWhen(
    data: (contacts) => contacts.isNotEmpty,
    orElse: () => false,
  );

  if (!hasContacts) return false;

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

/// Notifier para guardar información personal con loading/error state
class SavePersonalInfoNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> save() async {
    const tag = 'PersonalInfo';
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final authState = ref.read(authNotifierProvider);
      final userId = authState.valueOrNull?.id;

      if (userId == null) throw Exception('Usuario no autenticado');

      final formState = ref.read(personalInfoFormProvider);
      final dataSource = ref.read(personalInfoDataSourceProvider);

      AppLogger.d(
        'savePersonalInfo userId=$userId gender=${formState.gender} baptized=${formState.baptized}',
        tag: tag,
      );

      await dataSource.updatePersonalInfo(
        userId,
        gender: formState.gender,
        birthdate: formState.birthdate?.toUtc().toIso8601String(),
        baptized: formState.baptized,
        baptismDate: formState.baptismDate?.toUtc().toIso8601String(),
      );

      final selectedAllergies = ref.read(selectedAllergiesProvider);
      if (selectedAllergies.isNotEmpty) {
        await dataSource.saveUserAllergies(userId, selectedAllergies);
      }

      final selectedDiseases = ref.read(selectedDiseasesProvider);
      if (selectedDiseases.isNotEmpty) {
        await dataSource.saveUserDiseases(userId, selectedDiseases);
      }

      await dataSource.completeStep2(userId);
      AppLogger.i('Paso 2 completado', tag: tag);
    });
  }
}

/// Provider para guardar información personal
final savePersonalInfoProvider =
    AsyncNotifierProvider<SavePersonalInfoNotifier, void>(
  SavePersonalInfoNotifier.new,
);
