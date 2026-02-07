import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/emergency_contact_model.dart';
import '../models/legal_representative_model.dart';
import '../models/allergy_model.dart';
import '../models/disease_model.dart';
import '../models/relationship_type_model.dart';

/// Interface del data source remoto para información personal
abstract class PersonalInfoRemoteDataSource {
  /// Actualiza la información personal del usuario
  Future<void> updatePersonalInfo(
    String userId, {
    String? gender,
    String? birthdate,
    bool? baptized,
    String? baptismDate,
  });

  /// Obtiene los contactos de emergencia del usuario
  Future<List<EmergencyContactModel>> getEmergencyContacts(String userId);

  /// Agrega un contacto de emergencia
  Future<EmergencyContactModel> addEmergencyContact(
    String userId,
    EmergencyContactModel contact,
  );

  /// Actualiza un contacto de emergencia
  Future<EmergencyContactModel> updateEmergencyContact(
    int contactId,
    EmergencyContactModel contact,
  );

  /// Elimina un contacto de emergencia
  Future<void> deleteEmergencyContact(int contactId);

  /// Obtiene los tipos de relación disponibles
  Future<List<RelationshipTypeModel>> getRelationshipTypes();

  /// Verifica si el usuario requiere representante legal
  Future<bool> checkLegalRepresentativeRequired(String userId);

  /// Crea el representante legal del usuario
  Future<LegalRepresentativeModel> createLegalRepresentative(
    String userId,
    LegalRepresentativeModel representative,
  );

  /// Obtiene el representante legal del usuario
  Future<LegalRepresentativeModel?> getLegalRepresentative(String userId);

  /// Actualiza el representante legal del usuario
  Future<LegalRepresentativeModel> updateLegalRepresentative(
    String userId,
    LegalRepresentativeModel representative,
  );

  /// Obtiene el catálogo de alergias
  Future<List<AllergyModel>> getAllergiesCatalog();

  /// Guarda las alergias seleccionadas del usuario
  Future<void> saveUserAllergies(String userId, List<int> allergyIds);

  /// Obtiene el catálogo de enfermedades
  Future<List<DiseaseModel>> getDiseasesCatalog();

  /// Guarda las enfermedades seleccionadas del usuario
  Future<void> saveUserDiseases(String userId, List<int> diseaseIds);

  /// Completa el paso 2 del post-registro
  Future<void> completeStep2(String userId);
}

/// Implementación del data source remoto para información personal
class PersonalInfoRemoteDataSourceImpl implements PersonalInfoRemoteDataSource {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  PersonalInfoRemoteDataSourceImpl({
    required this.dio,
    required this.secureStorage,
  });

  /// Obtiene el token de autenticación
  Future<String> _getAuthToken() async {
    final token = await secureStorage.read(key: 'access_token');
    if (token == null) {
      throw Exception('No se encontró token de autenticación');
    }
    return token;
  }

  /// Configura los headers de autenticación
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
      if (birthdate != null) data['birthdate'] = birthdate;
      if (baptized != null) data['baptized'] = baptized;
      if (baptismDate != null) data['baptism_date'] = baptismDate;

      await dio.patch(
        '/users/$userId',
        data: data,
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al actualizar información personal: ${e.message}');
    }
  }

  @override
  Future<List<EmergencyContactModel>> getEmergencyContacts(String userId) async {
    try {
      final headers = await _getHeaders();
      final response = await dio.get(
        '/users/$userId/emergency-contacts',
        options: Options(headers: headers),
      );

      final List<dynamic> contactsJson = response.data as List<dynamic>;
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
        '/users/$userId/emergency-contacts',
        data: contact.toJson(),
        options: Options(headers: headers),
      );

      return EmergencyContactModel.fromJson(response.data as Map<String, dynamic>);
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
        '/emergency-contacts/$contactId',
        data: contact.toJson(),
        options: Options(headers: headers),
      );

      return EmergencyContactModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw Exception('Error al actualizar contacto de emergencia: ${e.message}');
    }
  }

  @override
  Future<void> deleteEmergencyContact(int contactId) async {
    try {
      final headers = await _getHeaders();
      await dio.delete(
        '/emergency-contacts/$contactId',
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
        '/catalogs/relationship-types',
        options: Options(headers: headers),
      );

      final List<dynamic> typesJson = response.data as List<dynamic>;
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
        '/users/$userId/requires-legal-representative',
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
        '/users/$userId/legal-representative',
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
        '/users/$userId/legal-representative',
        options: Options(headers: headers),
      );

      if (response.data == null) return null;
      return LegalRepresentativeModel.fromJson(response.data as Map<String, dynamic>);
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
        '/users/$userId/legal-representative',
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
        '/catalogs/allergies',
        options: Options(headers: headers),
      );

      final List<dynamic> allergiesJson = response.data as List<dynamic>;
      return allergiesJson
          .map((json) => AllergyModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener catálogo de alergias: ${e.message}');
    }
  }

  @override
  Future<void> saveUserAllergies(String userId, List<int> allergyIds) async {
    try {
      final headers = await _getHeaders();
      await dio.post(
        '/users/$userId/allergies',
        data: {'allergy_ids': allergyIds},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al guardar alergias: ${e.message}');
    }
  }

  @override
  Future<List<DiseaseModel>> getDiseasesCatalog() async {
    try {
      final headers = await _getHeaders();
      final response = await dio.get(
        '/catalogs/diseases',
        options: Options(headers: headers),
      );

      final List<dynamic> diseasesJson = response.data as List<dynamic>;
      return diseasesJson
          .map((json) => DiseaseModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception('Error al obtener catálogo de enfermedades: ${e.message}');
    }
  }

  @override
  Future<void> saveUserDiseases(String userId, List<int> diseaseIds) async {
    try {
      final headers = await _getHeaders();
      await dio.post(
        '/users/$userId/diseases',
        data: {'disease_ids': diseaseIds},
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al guardar enfermedades: ${e.message}');
    }
  }

  @override
  Future<void> completeStep2(String userId) async {
    try {
      final headers = await _getHeaders();
      await dio.post(
        '/users/$userId/post-registration/complete-step-2',
        options: Options(headers: headers),
      );
    } on DioException catch (e) {
      throw Exception('Error al completar paso 2: ${e.message}');
    }
  }
}
