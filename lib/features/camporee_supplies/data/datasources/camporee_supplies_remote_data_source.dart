import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../camporee_orders/domain/entities/camporee_order.dart';
import '../../domain/entities/camporee_supply_plan.dart';
import '../models/camporee_supply_plan_model.dart';

abstract class CamporeeSuppliesRemoteDataSource {
  Future<CamporeeSupplyPlanEnvelope> getPlan({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
    CancelToken? cancelToken,
  });

  Future<CamporeeSupplyPlan> replaceDraft({
    required int camporeeId,
    required List<CamporeeSupplyLineInput> lines,
    CamporeeKind camporeeType = CamporeeKind.local,
  });

  Future<CamporeeSupplyPlan> submit({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
  });

  Future<CamporeeSupplyPlan> adjustLine({
    required int camporeeId,
    required CamporeeSupplyLineInput line,
    CamporeeKind camporeeType = CamporeeKind.local,
  });
}

class CamporeeSuppliesRemoteDataSourceImpl
    implements CamporeeSuppliesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'CamporeeSuppliesDS';

  CamporeeSuppliesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String _camporeeBase(CamporeeKind kind) =>
      kind == CamporeeKind.union ? '/union-camporees' : '/camporees';

  @override
  Future<CamporeeSupplyPlanEnvelope> getPlan({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${_camporeeBase(camporeeType)}/$camporeeId/supply-plan',
        cancelToken: cancelToken,
      );
      return CamporeeSupplyPlanModel.envelopeFromJson(
        _unwrapMap(response.data),
        camporeeId: camporeeId,
        camporeeType: camporeeType,
      );
    } catch (e) {
      AppLogger.e('Error en getPlan', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeSupplyPlan> replaceDraft({
    required int camporeeId,
    required List<CamporeeSupplyLineInput> lines,
    CamporeeKind camporeeType = CamporeeKind.local,
  }) async {
    try {
      final response = await _dio.put(
        '$_baseUrl${_camporeeBase(camporeeType)}/$camporeeId/supply-plan',
        data: {'lines': lines.map((line) => line.toJson()).toList()},
      );
      return CamporeeSupplyPlanModel.planFromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en replaceDraft', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeSupplyPlan> submit({
    required int camporeeId,
    CamporeeKind camporeeType = CamporeeKind.local,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${_camporeeBase(camporeeType)}/$camporeeId/supply-plan/submit',
      );
      return CamporeeSupplyPlanModel.planFromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en submit', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<CamporeeSupplyPlan> adjustLine({
    required int camporeeId,
    required CamporeeSupplyLineInput line,
    CamporeeKind camporeeType = CamporeeKind.local,
  }) async {
    try {
      final response = await _dio.patch(
        '$_baseUrl${_camporeeBase(camporeeType)}/$camporeeId/supply-plan/lines',
        data: line.toJson(),
      );
      return CamporeeSupplyPlanModel.planFromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en adjustLine', tag: _tag, error: e);
      _rethrow(e);
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

  static const Map<String, String> _businessErrorKeys = {
    'CAMPOREE_SUPPLIES_NOT_FOUND': 'camporee_supplies.errors.not_found',
    'CAMPOREE_SUPPLIES_FORBIDDEN': 'camporee_supplies.errors.forbidden',
    'CAMPOREE_SUPPLIES_SECTION_NOT_ELIGIBLE':
        'camporee_supplies.errors.not_eligible',
    'CAMPOREE_SUPPLIES_DAY_LOCKED': 'camporee_supplies.errors.day_locked',
    'CAMPOREE_SUPPLIES_LINES_REQUIRED':
        'camporee_supplies.errors.lines_required',
    'CAMPOREE_SUPPLIES_PLAN_NOT_DRAFT': 'camporee_supplies.errors.not_draft',
    'CAMPOREE_SUPPLIES_PLAN_NOT_SUBMITTED':
        'camporee_supplies.errors.not_submitted',
    'CAMPOREE_SUPPLIES_QTY_INVALID': 'camporee_supplies.errors.qty_invalid',
  };

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      String? businessCode;
      try {
        final data = e.response?.data;
        if (data is Map) businessCode = data['code']?.toString();
      } catch (_) {}
      final i18nKey =
          businessCode != null ? _businessErrorKeys[businessCode] : null;
      if (i18nKey != null) {
        throw ServerException(
          message: tr(i18nKey),
          code: e.response?.statusCode,
        );
      }
      throw ServerException(
        message: e.message ?? tr('common.error_network'),
        code: e.response?.statusCode,
      );
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }
}
