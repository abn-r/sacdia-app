import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/emergency_contact_model.dart';
import '../models/legal_representative_model.dart';
import '../models/allergy_model.dart';
import '../models/disease_model.dart';
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
  Future<EmergencyContactModel> updateEmergencyContact(int contactId, EmergencyContactModel contact);
  Future<void> deleteEmergencyContact(int contactId);
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
  Future<void> completeStep2(String userId);
}

/// Implementación del data source remoto para información personal
class PersonalInfoRemoteDataSourceImpl implements PersonalInfoRemoteDataSource {
  final Dio dio;
  final String _baseUrl;
  final FlutterSecureStorage secureStorage;

  static const _tag = 'PersonalInfoDS';

  PersonalInfoRemoteDataSourceImpl({
    required this.dio,
    required String baseUrl,
    required this.secureStorage,
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

  Future<String> _getAuthToken() async {
    final token = await secureStorage.read(key: 'auth_token');
    if (token == null) {
      final allKeys = await secureStorage.readAll();
      AppLogger.w('Token null. Keys disponibles: ${allKeys.keys.toList()}', tag: _tag);
      throw Exception('No se encontró token de autenticación');
    }
    return token;
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getAuthToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
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
      final headers = await _getHeaders();
      final data = <String, dynamic>{};

      if (gender != null) data['gender'] = gender;
      if (birthdate != null) data['birthday'] = birthdate;
      if (baptized != null) data['baptism'] = baptized;
      if (baptized == true && baptismDate != null) {
        data['baptism_date'] = baptismDate;
      }

      final response = await dio.patch(
        '$_baseUrl/users/$userId',
        data: data,
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/users/$userId/emergency-contacts',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      final response = await dio.post(
        '$_baseUrl/users/$userId/emergency-contacts',
        data: contact.toJson(),
        options: Options(headers: headers),
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
    int contactId,
    EmergencyContactModel contact,
  ) async {
    try {
      final headers = await _getHeaders();
      final response = await dio.patch(
        '$_baseUrl/emergency-contacts/$contactId',
        data: contact.toJson(),
        options: Options(headers: headers),
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
  Future<void> deleteEmergencyContact(int contactId) async {
    try {
      final headers = await _getHeaders();
      await dio.delete(
        '$_baseUrl/emergency-contacts/$contactId',
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al eliminar contacto de emergencia: ${e.message}');
    }
  }

  @override
  Future<List<RelationshipTypeModel>> getRelationshipTypes() async {
    try {
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/catalogs/relationship-types',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/users/$userId/requires-legal-representative',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      final response = await dio.post(
        '$_baseUrl/users/$userId/legal-representative',
        data: representative.toJson(),
        options: Options(headers: headers),
      );

      return LegalRepresentativeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error al crear representante legal: ${e.message}');
    }
  }

  @override
  Future<LegalRepresentativeModel?> getLegalRepresentative(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/users/$userId/legal-representative',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      final response = await dio.patch(
        '$_baseUrl/users/$userId/legal-representative',
        data: representative.toJson(),
        options: Options(headers: headers),
      );

      return LegalRepresentativeModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error al actualizar representante legal: ${e.message}');
    }
  }

  @override
  Future<List<AllergyModel>> getAllergiesCatalog() async {
    try {
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/catalogs/allergies',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/users/$userId/allergies',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      await dio.put(
        '$_baseUrl/users/$userId/allergies',
        data: {'allergy_ids': allergyIds},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al guardar alergias: ${e.message}');
    }
  }

  @override
  Future<void> deleteUserAllergy(String userId, int allergyId) async {
    try {
      final headers = await _getHeaders();
      await dio.delete(
        '$_baseUrl/users/$userId/allergies/$allergyId',
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al eliminar alergia: ${e.message}');
    }
  }

  @override
  Future<List<DiseaseModel>> getDiseasesCatalog() async {
    try {
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/catalogs/diseases',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      final response = await dio.get(
        '$_baseUrl/users/$userId/diseases',
        options: Options(headers: headers),
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
      final headers = await _getHeaders();
      await dio.put(
        '$_baseUrl/users/$userId/diseases',
        data: {'disease_ids': diseaseIds},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al guardar enfermedades: ${e.message}');
    }
  }

  @override
  Future<void> deleteUserDisease(String userId, int diseaseId) async {
    try {
      final headers = await _getHeaders();
      await dio.delete(
        '$_baseUrl/users/$userId/diseases/$diseaseId',
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al eliminar enfermedad: ${e.message}');
    }
  }

  @override
  Future<void> completeStep2(String userId) async {
    try {
      final headers = await _getHeaders();
      await dio.post(
        '$_baseUrl/users/$userId/post-registration/step-2/complete',
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al completar paso 2: ${e.message}');
    }
  }
}
