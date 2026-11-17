import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/insurance_overview.dart';
import '../models/insurance_overview_model.dart';
import '../models/member_insurance_model.dart';

/// Remote reads of the insurance module.
///
/// Writes (issue an order, upload a receipt, reassign) live in
/// `payment_orders`: they are order operations, not insurance records.
abstract class InsuranceRemoteDataSource {
  /// `GET /club-sections/:sectionId/insurance/overview`.
  Future<InsuranceOverview> getOverview({
    required int sectionId,
    CancelToken? cancelToken,
  });

  /// `GET /club-sections/:sectionId/insurance/free-coverages`.
  Future<List<FreeCoverage>> getFreeCoverages({
    required int sectionId,
    CancelToken? cancelToken,
  });

  /// `GET /clubs/:clubId/sections/:sectionId/members/insurance`.
  ///
  /// Only the legacy camporee registration (field without payment orders)
  /// still reads it.
  Future<List<MemberInsuranceModel>> getMembersInsurance({
    required int clubId,
    required int sectionId,
    CancelToken? cancelToken,
  });
}

class InsuranceRemoteDataSourceImpl implements InsuranceRemoteDataSource {
  InsuranceRemoteDataSourceImpl({required Dio dio, required String baseUrl})
      : _dio = dio,
        _baseUrl = baseUrl;

  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'InsuranceDS';

  @override
  Future<InsuranceOverview> getOverview({
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubSections}/$sectionId/insurance/overview',
        cancelToken: cancelToken,
      );
      return InsuranceOverviewModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en getOverview', tag: _tag, error: e);
      _rethrow(e, 'insurance.errors.get_overview');
    }
  }

  @override
  Future<List<FreeCoverage>> getFreeCoverages({
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubSections}/$sectionId/insurance/'
        'free-coverages',
        cancelToken: cancelToken,
      );
      return InsuranceOverviewModel.freeCoveragesFromJson(
        _unwrapMap(response.data),
      );
    } catch (e) {
      AppLogger.e('Error en getFreeCoverages', tag: _tag, error: e);
      _rethrow(e, 'insurance.errors.get_free_coverages');
    }
  }

  @override
  Future<List<MemberInsuranceModel>> getMembersInsurance({
    required int clubId,
    required int sectionId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/sections/$sectionId/members/'
        'insurance',
        cancelToken: cancelToken,
      );
      final body = response.data;
      final List<dynamic> rawList = body is List
          ? body
          : (body is Map ? body['data'] as List<dynamic>? : null) ?? [];
      return rawList
          .map((e) => MemberInsuranceModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en getMembersInsurance', tag: _tag, error: e);
      _rethrow(e, 'insurance.errors.get_members');
    }
  }

  Map<String, dynamic> _unwrapMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    return <String, dynamic>{};
  }

  Never _rethrow(Object e, String fallbackKey) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      if (e.error is ConnectionException ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ConnectionException(message: tr('errors.connection_error'));
      }
      final data = e.response?.data;
      final code = data is Map ? data['code']?.toString() : null;
      throw ServerException(
        message: tr(fallbackKey),
        code: e.response?.statusCode,
        errorCode: code,
      );
    }
    if (e is AppException) throw e;
    throw ServerException(message: e.toString());
  }
}
