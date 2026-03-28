import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/role_assignment_model.dart';

abstract class RoleAssignmentsRemoteDataSource {
  Future<List<RoleAssignmentModel>> getAssignments();
}

class RoleAssignmentsRemoteDataSourceImpl
    implements RoleAssignmentsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;
  final FlutterSecureStorage _secureStorage;

  static const _tag = 'RoleAssignmentsDS';

  RoleAssignmentsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _secureStorage = const FlutterSecureStorage();

  Future<String> _getAuthToken() async {
    final token = await _secureStorage.read(key: 'auth_token');
    if (token == null) throw AuthException(message: 'No hay sesion activa');
    return token;
  }

  Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  Never _rethrow(Object e) {
    if (e is DioException) {
      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: e.response?.statusCode);
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is List) return msg.join(', ');
        return (msg ?? e.message ?? 'Error de conexion').toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? 'Error de conexion';
  }

  // ── GET /api/v1/requests/assignments ─────────────────────────────────────

  @override
  Future<List<RoleAssignmentModel>> getAssignments() async {
    try {
      final token = await _getAuthToken();
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.requests}/assignments',
        options: _authOptions(token),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        List<dynamic> data;

        if (responseData is Map && responseData.containsKey('data')) {
          data = responseData['data'] as List<dynamic>;
        } else if (responseData is List) {
          data = responseData;
        } else {
          data = [];
        }

        return data
            .map((json) => RoleAssignmentModel.fromJson(
                json as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
          message: 'Error al obtener asignaciones',
          code: response.statusCode);
    } catch (e) {
      AppLogger.e('Error en getAssignments', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
