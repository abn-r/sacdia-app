import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/supervision_annual_progress.dart';
import '../models/supervision_annual_progress_model.dart';

/// Server code of the 404 meaning "no annual configuration for this
/// local field, club type and year".
const String kAnnualConfigNotFoundCode = 'ANNUAL_RANKING_CONFIG_NOT_FOUND';

abstract class SupervisionAnnualProgressRemoteDataSource {
  /// GET /annual-rankings/territory-summary?division_id= (unions with their
  /// club count and whether they are configured); an older server answers
  /// 404 and the names come from GET /catalogs/unions?divisionId= instead.
  Future<List<SupervisionTerritoryOption>> getUnions(
    int divisionId, {
    CancelToken? cancelToken,
  });

  /// GET /annual-rankings/territory-summary?union_id= (same contract), with
  /// the same fallback to GET /catalogs/local-fields?unionId=.
  Future<List<SupervisionTerritoryOption>> getLocalFields(
    int unionId, {
    CancelToken? cancelToken,
  });

  /// GET /annual-rankings?local_field_id=&club_type_id=&year_id=
  Future<SupervisionAnnualProgress> getAnnualProgress(
    SupervisionAnnualProgressQuery query, {
    CancelToken? cancelToken,
  });
}

/// The territory summary endpoint is not on this server (404).
class _SummaryUnavailable implements Exception {
  const _SummaryUnavailable();
}

class SupervisionAnnualProgressRemoteDataSourceImpl
    implements SupervisionAnnualProgressRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionAnnualProgressDS';

  SupervisionAnnualProgressRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      // Only `code` and `message` are read; never `details`.
      throw businessErrorFrom(e);
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }

  bool _isOk(int? code) => code == 200 || code == 201;

  Object? _unwrap(Object? raw) =>
      raw is Map && raw.containsKey('data') ? raw['data'] : raw;

  Never _badResponse(Response<dynamic> response) => throw ServerException(
        message: 'Unexpected response (${response.statusCode})',
        code: response.statusCode,
      );

  @override
  Future<List<SupervisionTerritoryOption>> getUnions(
    int divisionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _territorySummary(
        'division_id',
        divisionId,
        cancelToken: cancelToken,
      );
    } on _SummaryUnavailable {
      return _catalogUnions(divisionId, cancelToken: cancelToken);
    } catch (e) {
      AppLogger.e('Error en getUnions (supervision progress)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<SupervisionTerritoryOption>> getLocalFields(
    int unionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _territorySummary(
        'union_id',
        unionId,
        cancelToken: cancelToken,
      );
    } on _SummaryUnavailable {
      return _catalogLocalFields(unionId, cancelToken: cancelToken);
    } catch (e) {
      AppLogger.e('Error en getLocalFields (supervision progress)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  /// One call for the territories below [parentKey] = [parentId]. A 404 means
  /// the server predates the endpoint: [_SummaryUnavailable].
  Future<List<SupervisionTerritoryOption>> _territorySummary(
    String parentKey,
    int parentId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/annual-rankings/territory-summary',
        queryParameters: {parentKey: parentId},
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionAnnualProgressModel.parseTerritorySummary(
        _unwrap(response.data),
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw const _SummaryUnavailable();
      rethrow;
    }
  }

  Future<List<SupervisionTerritoryOption>> _catalogUnions(
    int divisionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/unions',
        queryParameters: {'divisionId': divisionId},
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionAnnualProgressModel.parseOptions(
        _unwrap(response.data),
        idKey: 'union_id',
        parentKey: 'division_id',
        parentId: divisionId,
      );
    } catch (e) {
      AppLogger.e('Error en getUnions (supervision progress)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  Future<List<SupervisionTerritoryOption>> _catalogLocalFields(
    int unionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.catalogs}/local-fields',
        queryParameters: {'unionId': unionId},
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionAnnualProgressModel.parseOptions(
        _unwrap(response.data),
        idKey: 'local_field_id',
        parentKey: 'union_id',
        parentId: unionId,
      );
    } catch (e) {
      AppLogger.e('Error en getLocalFields (supervision progress)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionAnnualProgress> getAnnualProgress(
    SupervisionAnnualProgressQuery query, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/annual-rankings',
        queryParameters: {
          'local_field_id': query.localFieldId,
          'club_type_id': query.clubTypeId,
          'year_id': query.yearId,
        },
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionAnnualProgressModel.parse(_unwrap(response.data));
    } catch (e) {
      // A missing configuration is a normal state, not a failure.
      if (e is DioException &&
          e.response?.statusCode == 404 &&
          e.response?.data is Map &&
          (e.response!.data as Map)['code'] == kAnnualConfigNotFoundCode) {
        return const SupervisionAnnualProgress(configured: false);
      }
      AppLogger.e('Error en getAnnualProgress (supervision progress)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
