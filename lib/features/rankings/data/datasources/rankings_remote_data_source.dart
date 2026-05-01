import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../providers/dio_provider.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/member_breakdown_dto.dart';
import '../models/member_ranking_dto.dart';
import '../models/section_ranking_dto.dart';

/// Typed signal thrown when backend responds 403 MEMBER_RANKING_HIDDEN.
/// The repository catches this and maps it to [Right(null)] — graceful empty state.
class MemberRankingHiddenException extends AppException {
  MemberRankingHiddenException()
      : super(
          message: 'member_rankings.visibility_hidden',
          code: 403,
        );
}

/// Interface for the rankings remote data source.
abstract class RankingsRemoteDataSource {
  /// `GET /member-rankings/me?year_id=[yearId]`
  ///
  /// Throws [MemberRankingHiddenException] when visibility_mode = hidden.
  /// Throws [AuthException] on other 403s.
  /// Throws [ServerException] on other errors.
  Future<MyRankingResponseDto> getMyRanking(
    int yearId, {
    CancelToken? cancelToken,
  });

  /// `GET /member-rankings/:enrollmentId/breakdown?year_id=[yearId]`
  ///
  /// Returns the per-component score breakdown for a specific enrollment.
  /// Throws [AuthException] on 403.
  /// Throws [ServerException] on other errors.
  Future<MemberBreakdownDtoModel> getBreakdown(
    int enrollmentId,
    int yearId, {
    CancelToken? cancelToken,
  });

  /// `GET /section-rankings?year_id=[yearId]&club_id=[clubId]`
  ///
  /// Returns the paginated `data` array.
  Future<List<SectionRankingDto>> getSectionRankings({
    required int yearId,
    int? clubId,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  });

  /// `GET /section-rankings/:sectionId/members?year_id=[yearId]`
  Future<List<SectionMemberDto>> getSectionMembers(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  });
}

/// Implementation of [RankingsRemoteDataSource] using [Dio].
class RankingsRemoteDataSourceImpl implements RankingsRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'RankingsDS';

  RankingsRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _extractErrorCode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        // Backend sends { code: 'MEMBER_RANKING_HIDDEN', message: '...' }
        final code = data['code'];
        if (code is String) return code;
      }
    } catch (_) {}
    return '';
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'];
        if (msg is List) return msg.join(', ');
        return (msg ?? e.message ?? tr('common.error_network')).toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }

  Never _rethrow(Object e) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;

      if (statusCode == 401) {
        // Expired token / not authenticated → AuthException so repo maps to Left(AuthFailure)
        throw AuthException(
          message: _extractDioMessage(e),
          code: 401,
        );
      }

      if (statusCode == 403) {
        final code = _extractErrorCode(e);
        if (code == 'MEMBER_RANKING_HIDDEN') {
          throw MemberRankingHiddenException();
        }
        // Other 403 → AuthException so repo maps to Left(AuthFailure)
        throw AuthException(
          message: _extractDioMessage(e),
          code: statusCode,
        );
      }

      // Mid-flight network errors (timeout, connection drop) — no response
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ServerException(message: tr('common.error_network'), code: null);
      }

      final msg = _extractDioMessage(e);
      throw ServerException(message: msg, code: statusCode);
    }
    if (e is MemberRankingHiddenException ||
        e is ServerException ||
        e is AuthException) {
      throw e;
    }
    throw ServerException(message: e.toString());
  }

  // ── GET /member-rankings/me ───────────────────────────────────────────────────

  @override
  Future<MyRankingResponseDto> getMyRanking(
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.memberRankings}/me',
        queryParameters: {'year_id': yearId},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final json = data is Map && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return MyRankingResponseDto.fromJson(json);
      }

      throw ServerException(
        message: tr('member_rankings.errors.get_my_ranking'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getMyRanking', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /member-rankings/:enrollmentId/breakdown ─────────────────────────────

  @override
  Future<MemberBreakdownDtoModel> getBreakdown(
    int enrollmentId,
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.memberRankings}/$enrollmentId/breakdown',
        queryParameters: {'year_id': yearId},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final json = data is Map && data.containsKey('data')
            ? data['data'] as Map<String, dynamic>
            : data as Map<String, dynamic>;
        return MemberBreakdownDtoModel.fromJson(json);
      }

      throw ServerException(
        message: tr('member_rankings.errors.get_breakdown'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getBreakdown', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /section-rankings ─────────────────────────────────────────────────────

  @override
  Future<List<SectionRankingDto>> getSectionRankings({
    required int yearId,
    int? clubId,
    int page = 1,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'year_id': yearId,
        'page': page,
        'limit': limit,
      };
      if (clubId != null) queryParams['club_id'] = clubId;

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.sectionRankings}',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final body = response.data;
        // Backend returns { data: [...], total, page, limit }
        final rawList = body is Map
            ? (body['data'] as List<dynamic>? ?? [])
            : (body as List<dynamic>? ?? []);
        return rawList
            .map((e) => SectionRankingDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('section_rankings.errors.get_rankings'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getSectionRankings', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /section-rankings/:sectionId/members ──────────────────────────────────

  @override
  Future<List<SectionMemberDto>> getSectionMembers(
    int sectionId,
    int yearId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.sectionRankings}/$sectionId/members',
        queryParameters: {'year_id': yearId},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200) {
        final body = response.data;
        // Backend returns a plain array (MemberRankingResponseDto[])
        final rawList = body as List<dynamic>? ?? <dynamic>[];
        return rawList
            .map((e) => SectionMemberDto.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('section_rankings.errors.get_members'),
        code: response.statusCode,
      );
    } catch (e) {
      if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      AppLogger.e('Error en getSectionMembers', tag: _tag, error: e);
      _rethrow(e);
    }
  }
}

// ── Infrastructure provider ───────────────────────────────────────────────────

/// Provider for the shared rankings remote data source.
/// Co-located with [RankingsRemoteDataSource] following Clean Architecture
/// (infrastructure dependency belongs in the data layer).
/// Both member and section repository providers read from this single instance.
final rankingsRemoteDataSourceProvider =
    Provider<RankingsRemoteDataSource>((ref) {
  return RankingsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: AppConstants.baseUrl,
  );
});
