import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/network/interceptors/auth_interceptor.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/linked_device.dart';
import '../models/linked_device_models.dart';

abstract class LinkedDevicesRemoteDataSource {
  Future<LinkedDevices> list(String dependentId);

  Future<DevicePairingToken> issuePairingToken(String dependentId);

  Future<RevokedDevice> revoke(String dependentId, String deviceId);
}

class LinkedDevicesRemoteDataSourceImpl
    implements LinkedDevicesRemoteDataSource {
  LinkedDevicesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
    DateTime Function()? now,
  })  : _dio = dio,
        _baseUrl = baseUrl,
        _now = now ?? DateTime.now;

  final Dio _dio;
  final String _baseUrl;
  final DateTime Function() _now;

  static const _tag = 'LinkedDevicesDS';

  String _devices(String dependentId) =>
      '$_baseUrl${ApiEndpoints.guardianships}/me/dependents/$dependentId/devices';

  /// El tutor gestiona los teléfonos desde su perfil PROPIO: nunca lleva
  /// `X-Acting-For`.
  Options get _options =>
      Options(extra: const {AuthInterceptor.skipActingForKey: true});

  Map<String, dynamic> _unwrap(Object? raw) {
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    throw ServerException(message: tr('errors.server_error'));
  }

  Future<T> _run<T>(
    String label,
    Future<Response<dynamic>> Function() request,
    T Function(Map<String, dynamic> data) parse,
  ) async {
    try {
      final response = await request();
      final status = response.statusCode;
      if (status == null || status < 200 || status >= 300) {
        throw appExceptionFromResponse(status, response.data);
      }
      return parse(_unwrap(response.data));
    } catch (e) {
      // Nunca se registra el cuerpo: el token de vinculación es un secreto.
      AppLogger.e('Error en $label', tag: _tag, error: e.runtimeType);
      rethrowApiError(e);
    }
  }

  @override
  Future<LinkedDevices> list(String dependentId) => _run(
        'listLinkedDevices',
        () => _dio.get(_devices(dependentId), options: _options),
        LinkedDeviceJson.list,
      );

  @override
  Future<DevicePairingToken> issuePairingToken(String dependentId) => _run(
        'issuePairingToken',
        () => _dio.post(
          '${_devices(dependentId)}/pairing-tokens',
          data: const <String, dynamic>{},
          options: _options,
        ),
        (data) => LinkedDeviceJson.pairingToken(data, now: _now()),
      );

  @override
  Future<RevokedDevice> revoke(String dependentId, String deviceId) => _run(
        'revokeLinkedDevice',
        () => _dio.post(
          '${_devices(dependentId)}/$deviceId/revoke',
          data: const <String, dynamic>{},
          options: _options,
        ),
        LinkedDeviceJson.revoked,
      );
}
