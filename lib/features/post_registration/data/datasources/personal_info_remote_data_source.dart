import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../models/emergency_contact_model.dart';
import '../models/legal_representative_model.dart';
import '../models/allergy_model.dart';
import '../models/disease_model.dart';
import '../models/medicine_model.dart';
import '../models/relationship_type_model.dart';
import '../../../../core/utils/app_logger.dart';

/// Interface del data source remoto para información personal
abstract class PersonalInfoRemoteDataSource {
  Future<void> updatePersonalInfo(
    String userId, {
    String? gender,
    String? birthdate,
    bool? baptized,
    String? baptismDate,
  });

  Future<List<EmergencyContactModel>> getEmergencyContacts(String userId);
  Future<EmergencyContactModel> addEmergencyContact(String userId, EmergencyContactModel contact);
  Future<EmergencyContactModel> updateEmergencyContact(String userId, int contactId, EmergencyContactModel contact);
  Future<void> deleteEmergencyContact(String userId, int contactId);
  Future<List<RelationshipTypeModel>> getRelationshipTypes();
  Future<bool> checkLegalRepresentativeRequired(String userId);
  Future<LegalRepresentativeModel> createLegalRepresentative(String userId, LegalRepresentativeModel representative);
  Future<LegalRepresentativeModel?> getLegalRepresentative(String userId);
  Future<LegalRepresentativeModel> updateLegalRepresentative(String userId, LegalRepresentativeModel representative);
  Future<List<AllergyModel>> getAllergiesCatalog();
  Future<List<AllergyModel>> getUserAllergies(String userId);
  Future<void> saveUserAllergies(String userId, List<int> allergyIds);
  Future<void> deleteUserAllergy(String userId, int allergyId);
  Future<List<DiseaseModel>> getDiseasesCatalog();
  Future<List<DiseaseModel>> getUserDiseases(String userId);
  Future<void> saveUserDiseases(String userId, List<int> diseaseIds);
  Future<void> deleteUserDisease(String userId, int diseaseId);
  Future<List<MedicineModel>> getMedicinesCatalog();
  Future<List<MedicineModel>> getUserMedicines(String userId);
  Future<void> saveUserMedicines(String userId, List<int> medicineIds);
  Future<void> deleteUserMedicine(String userId, int medicineId);
  Future<void> completeStep2(String userId);
}

/// Implementación del data source remoto para información personal
class PersonalInfoRemoteDataSourceImpl implements PersonalInfoRemoteDataSource {
  final Dio dio;
  final String _baseUrl;

  static const _tag = 'PersonalInfoDS';

  PersonalInfoRemoteDataSourceImpl({
    required this.dio,
    required String baseUrl,
  }) : _baseUrl = baseUrl;

  /// Helper: extrae una lista desde la respuesta de la API.
  List<dynamic> _extractList(dynamic responseData) {
    if (responseData is List) return responseData;
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is List) return data;
    }
    return [];
  }

  @override
  Future<void> updatePersonalInfo(
    String userId, {
    String? gender,
    String? birthdate,
    bool? baptized,
    String? baptismDate,
  }) async {
    try {

      final data = <String, dynamic>{};

      if (gender != null) data['gender'] = gender;
      if (birthdate != null) data['birthday'] = birthdate;
      if (baptized != null) data['baptism'] = baptized;
      if (baptized == true && baptismDate != null) {
        data['baptism_date'] = baptismDate;
      }

      final response = await dio.patch(
        '$_baseUrl${ApiEndpoints.users}/$userId',
        data: data,

      );

      AppLogger.d('PATCH /users/$userId ${response.statusCode}', tag: _tag);
    } on DioException catch (e) {
      AppLogger.e('Error PATCH /users/$userId', tag: _tag, error: e.response?.data ?? e.message);
      throw Exception('Error al actualizar información personal: ${e.message}');
    }
  }

  @override
  Future<List<EmergencyContactModel>> getEmergencyContacts(String userId) async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/emergency-contacts',

      );

      final contactsJson = _extractList(response.data);
      return contactsJson
          .map((json) => EmergencyContactModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener contactos de emergencia: ${e.message}');
    }
  }

  @override
  Future<EmergencyContactModel> addEmergencyContact(
    String userId,
    EmergencyContactModel contact,
  ) async {
    try {

      final response = await dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/emergency-contacts',
        data: contact.toJson(),

      );

      final responseData = response.data is Map<String, dynamic> &&
              response.data['data'] is Map<String, dynamic>
          ? response.data['data'] as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      return EmergencyContactModel.fromJson(responseData);
    } on DioException catch (e) {
      throw Exception('Error al agregar contacto de emergencia: ${e.message}');
    }
  }

  @override
  Future<EmergencyContactModel> updateEmergencyContact(
    String userId,
    int contactId,
    EmergencyContactModel contact,
  ) async {
    try {

      final response = await dio.patch(
        '$_baseUrl${ApiEndpoints.users}/$userId/emergency-contacts/$contactId',
        data: contact.toJson(),

      );

      final responseData = response.data is Map<String, dynamic> &&
              response.data['data'] is Map<String, dynamic>
          ? response.data['data'] as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      return EmergencyContactModel.fromJson(responseData);
    } on DioException catch (e) {
      throw Exception('Error al actualizar contacto de emergencia: ${e.message}');
    }
  }

  @override
  Future<void> deleteEmergencyContact(String userId, int contactId) async {
    try {

      await dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/emergency-contacts/$contactId',

      );
    } on DioException catch (e) {
      throw Exception('Error al eliminar contacto de emergencia: ${e.message}');
    }
  }

  @override
  Future<List<RelationshipTypeModel>> getRelationshipTypes() async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/relationship-types',

      );

      final typesJson = _extractList(response.data);
      return typesJson
          .map((json) => RelationshipTypeModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener tipos de relación: ${e.message}');
    }
  }

  @override
  Future<bool> checkLegalRepresentativeRequired(String userId) async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/requires-legal-representative',

      );

      return response.data['required'] as bool;
    } on DioException catch (e) {
      throw Exception('Error al verificar representante legal: ${e.message}');
    }
  }

  @override
  Future<LegalRepresentativeModel> createLegalRepresentative(
    String userId,
    LegalRepresentativeModel representative,
  ) async {
    try {

      final response = await dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/legal-representative',
        data: representative.toJson(),

      );

      return LegalRepresentativeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error al crear representante legal: ${e.message}');
    }
  }

  @override
  Future<LegalRepresentativeModel?> getLegalRepresentative(String userId) async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/legal-representative',

      );

      final responseData = response.data;
      if (responseData == null) return null;

      if (responseData is Map<String, dynamic>) {
        final data = responseData['data'];
        if (data == null) return null;
        return LegalRepresentativeModel.fromJson(data as Map<String, dynamic>);
      }

      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception('Error al obtener representante legal: ${e.message}');
    }
  }

  @override
  Future<LegalRepresentativeModel> updateLegalRepresentative(
    String userId,
    LegalRepresentativeModel representative,
  ) async {
    try {

      final response = await dio.patch(
        '$_baseUrl${ApiEndpoints.users}/$userId/legal-representative',
        data: representative.toJson(),

      );

      return LegalRepresentativeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error al actualizar representante legal: ${e.message}');
    }
  }

  @override
  Future<List<AllergyModel>> getAllergiesCatalog() async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/allergies',

      );

      final allergiesJson = _extractList(response.data);
      return allergiesJson
          .map((json) => AllergyModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener catálogo de alergias: ${e.message}');
    }
  }

  @override
  Future<List<AllergyModel>> getUserAllergies(String userId) async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/allergies',

      );

      final allergiesJson = _extractList(response.data);
      return allergiesJson
          .map((json) => AllergyModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception('Error al obtener alergias del usuario: ${e.message}');
    }
  }

  @override
  Future<void> saveUserAllergies(String userId, List<int> allergyIds) async {
    try {

      await dio.put(
        '$_baseUrl${ApiEndpoints.users}/$userId/allergies',
        data: {'allergy_ids': allergyIds},

      );
    } on DioException catch (e) {
      throw Exception('Error al guardar alergias: ${e.message}');
    }
  }

  @override
  Future<void> deleteUserAllergy(String userId, int allergyId) async {
    try {

      await dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/allergies/$allergyId',

      );
    } on DioException catch (e) {
      throw Exception('Error al eliminar alergia: ${e.message}');
    }
  }

  @override
  Future<List<DiseaseModel>> getDiseasesCatalog() async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/diseases',

      );

      final diseasesJson = _extractList(response.data);
      return diseasesJson
          .map((json) => DiseaseModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener catálogo de enfermedades: ${e.message}');
    }
  }

  @override
  Future<List<DiseaseModel>> getUserDiseases(String userId) async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/diseases',

      );

      final diseasesJson = _extractList(response.data);
      return diseasesJson
          .map((json) => DiseaseModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception('Error al obtener enfermedades del usuario: ${e.message}');
    }
  }

  @override
  Future<void> saveUserDiseases(String userId, List<int> diseaseIds) async {
    try {

      await dio.put(
        '$_baseUrl${ApiEndpoints.users}/$userId/diseases',
        data: {'disease_ids': diseaseIds},

      );
    } on DioException catch (e) {
      throw Exception('Error al guardar enfermedades: ${e.message}');
    }
  }

  @override
  Future<void> deleteUserDisease(String userId, int diseaseId) async {
    try {

      await dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/diseases/$diseaseId',

      );
    } on DioException catch (e) {
      throw Exception('Error al eliminar enfermedad: ${e.message}');
    }
  }

  @override
  Future<List<MedicineModel>> getMedicinesCatalog() async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/medicines',

      );

      final medicinesJson = _extractList(response.data);
      return medicinesJson
          .map((json) => MedicineModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener catálogo de medicamentos: ${e.message}');
    }
  }

  @override
  Future<List<MedicineModel>> getUserMedicines(String userId) async {
    try {

      final response = await dio.get(
        '$_baseUrl${ApiEndpoints.users}/$userId/medicines',

      );

      final medicinesJson = _extractList(response.data);
      return medicinesJson
          .map((json) => MedicineModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      throw Exception('Error al obtener medicamentos del usuario: ${e.message}');
    }
  }

  @override
  Future<void> saveUserMedicines(String userId, List<int> medicineIds) async {
    try {

      await dio.put(
        '$_baseUrl${ApiEndpoints.users}/$userId/medicines',
        data: {'medicine_ids': medicineIds},

      );
    } on DioException catch (e) {
      throw Exception('Error al guardar medicamentos: ${e.message}');
    }
  }

  @override
  Future<void> deleteUserMedicine(String userId, int medicineId) async {
    try {

      await dio.delete(
        '$_baseUrl${ApiEndpoints.users}/$userId/medicines/$medicineId',

      );
    } on DioException catch (e) {
      throw Exception('Error al eliminar medicamento: ${e.message}');
    }
  }

  @override
  Future<void> completeStep2(String userId) async {
    try {

      await dio.post(
        '$_baseUrl${ApiEndpoints.users}/$userId/post-registration/step-2/complete',

      );
    } on DioException catch (e) {
      throw Exception('Error al completar paso 2: ${e.message}');
    }
  }
}
