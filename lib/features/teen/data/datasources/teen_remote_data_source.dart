import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/network/api_error_mapper.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/teen_supervision.dart';
import '../models/teen_models.dart';

/// Fuente remota de `/users/me/supervision` y los vínculos con el tutor.
abstract class TeenRemoteDataSource {
  Future<TeenSupervision> getSupervision();

  Future<TeenLinkCode> issueLinkCode();

  Future<void> revokePendingLink(String guardianshipId);
}

class TeenRemoteDataSourceImpl implements TeenRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'TeenDS';

  TeenRemoteDataSourceImpl({required Dio dio, required String baseUrl})
      : _dio = dio,
        _baseUrl = baseUrl;

  String get _me => '$_baseUrl${ApiEndpoints.users}/me';

  Map<String, dynamic> _unwrap(Object? raw) {
    if (raw is Map && raw['data'] is Map) {
      return Map<String, dynamic>.from(raw['data'] as Map);
    }
    throw ServerException(message: tr('errors.server_error'));
  }

  bool _isOk(Response<dynamic> r) =>
      r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  Future<Response<dynamic>> _send(
    String label,
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      if (!_isOk(response)) {
        throw appExceptionFromResponse(response.statusCode, response.data);
      }
      return response;
    } catch (e) {
      AppLogger.e('Error en $label', tag: _tag, error: e.runtimeType);
      rethrowApiError(e);
    }
  }

  @override
  Future<TeenSupervision> getSupervision() async {
    final response =
        await _send('getSupervision', () => _dio.get('$_me/supervision'));
    return TeenJson.supervision(_unwrap(response.data));
  }

  @override
  Future<TeenLinkCode> issueLinkCode() async {
    final response = await _send(
      'issueLinkCode',
      () => _dio
          .post('$_me/guardian-link-codes', data: const <String, dynamic>{}),
    );
    return TeenJson.linkCode(_unwrap(response.data));
  }

  @override
  Future<void> revokePendingLink(String guardianshipId) async {
    await _send(
      'revokePendingLink',
      () => _dio.post(
        '$_me/guardian-links/$guardianshipId/revoke',
        data: const <String, dynamic>{},
      ),
    );
  }
}
