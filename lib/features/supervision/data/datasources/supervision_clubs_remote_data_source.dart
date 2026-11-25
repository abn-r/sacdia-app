import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/supervision_club.dart';
import '../models/supervision_club_model.dart';

abstract class SupervisionClubsRemoteDataSource {
  /// GET /clubs (the server applies the territory cut)
  Future<SupervisionClubPage> getClubs({
    required SupervisionClubActiveFilter filter,
    required String search,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  });

  /// GET /clubs/:clubId
  Future<SupervisionClubProfile> getClub(
    int clubId, {
    CancelToken? cancelToken,
  });

  /// GET /clubs/:clubId/overview
  Future<SupervisionClubOverview> getOverview(
    int clubId, {
    CancelToken? cancelToken,
  });

  /// GET /clubs/:clubId/leadership
  Future<SupervisionClubLeadership> getLeadership(
    int clubId, {
    CancelToken? cancelToken,
  });
}

class SupervisionClubsRemoteDataSourceImpl
    implements SupervisionClubsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionClubsDS';

  SupervisionClubsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String get _root => '$_baseUrl${ApiEndpoints.clubs}';

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (isAuthorizationStale(e)) throw authorizationStaleException(e);
      // Only `code` and `message` are read; never `details`.
      throw businessErrorFrom(e, fallbackMessage: tr('common.error_network'));
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }

  bool _isOk(int? code) => code == 200 || code == 201;

  Never _badResponse(Response<dynamic> response) => throw ServerException(
        message: tr('common.error_network'),
        code: response.statusCode,
      );

  @override
  Future<SupervisionClubPage> getClubs({
    required SupervisionClubActiveFilter filter,
    required String search,
    required int page,
    required int limit,
    CancelToken? cancelToken,
  }) async {
    try {
      final term = search.trim();
      final response = await _dio.get(
        _root,
        queryParameters: {
          if (term.isNotEmpty) 'search': term,
          if (filter != SupervisionClubActiveFilter.all)
            'active':
                filter == SupervisionClubActiveFilter.active ? 'true' : 'false',
          'page': page,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionClubModel.parsePage(response.data);
    } catch (e) {
      AppLogger.e('Error en getClubs (supervision clubs)', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionClubProfile> getClub(
    int clubId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_root/$clubId',
        cancelToken: cancelToken,
      );
      if (_isOk(response.statusCode)) {
        final profile = SupervisionClubModel.tryParseProfile(response.data);
        if (profile != null) return profile;
      }
      _badResponse(response);
    } catch (e) {
      AppLogger.e('Error en getClub (supervision clubs)', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionClubOverview> getOverview(
    int clubId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_root/$clubId/overview',
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionClubModel.parseOverview(response.data);
    } catch (e) {
      AppLogger.e('Error en getOverview (supervision clubs)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionClubLeadership> getLeadership(
    int clubId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_root/$clubId/leadership',
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionClubModel.parseLeadership(response.data);
    } catch (e) {
      AppLogger.e('Error en getLeadership (supervision clubs)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
