import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/device_pairing.dart';
import '../models/device_pairing_models.dart';

abstract class DevicePairingRemoteDataSource {
  Future<DevicePairingSession> pair(DevicePairingInput input);
}

class DevicePairingRemoteDataSourceImpl
    implements DevicePairingRemoteDataSource {
  DevicePairingRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'DevicePairingDS';

  @override
  Future<DevicePairingSession> pair(DevicePairingInput input) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.auth}/device/pair',
        // El cuerpo lleva el token de un solo uso: no se registra en ningún
        // lado (el interceptor de log solo imprime método y ruta).
        data: {
          'pairing_token': input.pairingToken,
          'label': input.label,
          'platform': input.platform,
          'app_version': input.appVersion,
        },
        options: Options(
          // Ruta pública: no hay sesión ni perfil por el que actuar.
          extra: const {AuthInterceptor.skipActingForKey: true},
        ),
      );
      final status = response.statusCode;
      if (status == null || status < 200 || status >= 300) {
        throw appExceptionFromResponse(status, response.data);
      }
      return DevicePairingJson.session(response.data);
    } catch (e) {
      // Nunca se registra el error crudo: podría eco-ar la petición.
      AppLogger.e('Error al vincular el dispositivo',
          tag: _tag, error: e.runtimeType);
      if (e is AppException) rethrow;
      rethrowApiError(e);
    }
  }
}
