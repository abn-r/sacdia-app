import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/payment_order_model.dart';

/// Fuente de datos remota para órdenes de pago territoriales.
abstract class PaymentOrdersRemoteDataSource {
  /// GET /payment-orders/context — flag + ciclos aplicables a la sección activa.
  Future<PaymentOrdersContextModel> getContext({CancelToken? cancelToken});

  /// POST /insurance/payment-orders — emite orden grupal de seguro.
  Future<PaymentOrderModel> createInsuranceOrder({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
  });

  /// POST /camporees/:camporeeId/payment-orders (local) o
  /// POST /union-camporees/:camporeeId/payment-orders (unión) — emite orden
  /// de camporee. En ambos casos cobra el Campo Local del emisor.
  Future<PaymentOrderModel> createCamporeeOrder({
    required int camporeeId,
    required List<String> beneficiaryUserIds,
    String camporeeType = 'local',
  });

  /// GET /payment-orders — lista órdenes del alcance del actor.
  Future<List<PaymentOrderModel>> listOrders({
    String? purpose,
    String? status,
    int? camporeeId,
    int? unionCamporeeId,
    CancelToken? cancelToken,
  });

  /// GET /payment-orders/:orderId — detalle con líneas y comprobantes.
  Future<PaymentOrderModel> getOrder(
    String orderId, {
    CancelToken? cancelToken,
  });

  /// GET /payment-orders/:orderId/document — descarga el PDF a un archivo
  /// temporal y regresa la ruta local.
  Future<String> downloadOrderPdf(String orderId, {CancelToken? cancelToken});

  /// POST /payment-orders/:orderId/proof — sube el comprobante (multipart).
  Future<PaymentOrderModel> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  /// POST /payment-orders/:orderId/cancel — cancela una orden emitida/rechazada.
  Future<PaymentOrderModel> cancelOrder(String orderId);

  /// POST /insurance/reassignments — solicita reasignar cobertura activa.
  Future<InsuranceReassignmentModel> createReassignment({
    required int insuranceAssignmentId,
    required String toUserId,
    String? reason,
  });

  /// GET /insurance/reassignments — lista solicitudes del alcance.
  Future<List<InsuranceReassignmentModel>> listReassignments({
    String? status,
    CancelToken? cancelToken,
  });
}

/// Implementación con Dio de la fuente de datos de órdenes de pago.
class PaymentOrdersRemoteDataSourceImpl implements PaymentOrdersRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'PaymentOrdersDS';

  PaymentOrdersRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  @override
  Future<PaymentOrdersContextModel> getContext({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.paymentOrders}/context',
        cancelToken: cancelToken,
      );
      return PaymentOrdersContextModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en getContext', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<PaymentOrderModel> createInsuranceOrder({
    required int cycleConfigId,
    required List<String> beneficiaryUserIds,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.insurance}/payment-orders',
        data: {
          'insurance_cycle_config_id': cycleConfigId,
          'beneficiary_user_ids': beneficiaryUserIds,
        },
      );
      return PaymentOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en createInsuranceOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<PaymentOrderModel> createCamporeeOrder({
    required int camporeeId,
    required List<String> beneficiaryUserIds,
    String camporeeType = 'local',
  }) async {
    try {
      final basePath = camporeeType == 'union'
          ? ApiEndpoints.unionCamporees
          : ApiEndpoints.camporees;
      final response = await _dio.post(
        '$_baseUrl$basePath/$camporeeId/payment-orders',
        data: {'beneficiary_user_ids': beneficiaryUserIds},
      );
      return PaymentOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en createCamporeeOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<PaymentOrderModel>> listOrders({
    String? purpose,
    String? status,
    int? camporeeId,
    int? unionCamporeeId,
    CancelToken? cancelToken,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (purpose != null) 'purpose': purpose,
        if (status != null) 'status': status,
        if (camporeeId != null) 'camporee_id': camporeeId,
        if (unionCamporeeId != null) 'union_camporee_id': unionCamporeeId,
      };
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.paymentOrders}',
        queryParameters: queryParams.isEmpty ? null : queryParams,
        cancelToken: cancelToken,
      );
      return _unwrapList(response.data)
          .map((e) => PaymentOrderModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en listOrders', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<PaymentOrderModel> getOrder(
    String orderId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.paymentOrders}/$orderId',
        cancelToken: cancelToken,
      );
      return PaymentOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en getOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<String> downloadOrderPdf(
    String orderId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/sacdia_payment_order_${orderId}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      // El AuthInterceptor agrega el Bearer; el token nunca va en la URL.
      await _dio.download(
        '$_baseUrl${ApiEndpoints.paymentOrders}/$orderId/document',
        filePath,
        cancelToken: cancelToken,
        options: Options(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final file = File(filePath);
      if (!await file.exists() || await file.length() == 0) {
        throw ServerException(
          message: tr('payment_orders.errors.download_document'),
        );
      }
      return filePath;
    } catch (e) {
      AppLogger.e('Error en downloadOrderPdf', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<PaymentOrderModel> uploadProof({
    required String orderId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
          contentType: DioMediaType.parse(mimeType),
        ),
      });
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.paymentOrders}/$orderId/proof',
        data: formData,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );
      return PaymentOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en uploadProof', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<PaymentOrderModel> cancelOrder(String orderId) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.paymentOrders}/$orderId/cancel',
      );
      return PaymentOrderModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en cancelOrder', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<InsuranceReassignmentModel> createReassignment({
    required int insuranceAssignmentId,
    required String toUserId,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.insurance}/reassignments',
        data: {
          'insurance_assignment_id': insuranceAssignmentId,
          'to_user_id': toUserId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      return InsuranceReassignmentModel.fromJson(_unwrapMap(response.data));
    } catch (e) {
      AppLogger.e('Error en createReassignment', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<InsuranceReassignmentModel>> listReassignments({
    String? status,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.insurance}/reassignments',
        queryParameters: status != null ? {'status': status} : null,
        cancelToken: cancelToken,
      );
      return _unwrapList(response.data)
          .map((e) =>
              InsuranceReassignmentModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Error en listReassignments', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  Map<String, dynamic> _unwrapMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is Map<String, dynamic>) return data;
      return body;
    }
    return <String, dynamic>{};
  }

  List<dynamic> _unwrapList(dynamic body) {
    if (body is List) return body;
    if (body is Map<String, dynamic>) {
      final data = body['data'];
      if (data is List) return data;
    }
    return const [];
  }

  /// Claves i18n para los códigos de negocio del backend.
  static const Map<String, String> _businessErrorKeys = {
    'FIELD_PAYMENT_ORDER_FLAG_DISABLED':
        'payment_orders.errors.flag_disabled',
    'FIELD_PAYMENT_ORDER_EXPIRED': 'payment_orders.errors.expired',
    'FIELD_PAYMENT_ORDER_DUPLICATE_BENEFICIARY':
        'payment_orders.errors.duplicate_beneficiary',
    'FIELD_PAYMENT_ORDER_BENEFICIARIES_REQUIRED':
        'payment_orders.errors.beneficiaries_required',
    'FIELD_PAYMENT_ORDER_INVALID_TRANSITION':
        'payment_orders.errors.invalid_transition',
    'FIELD_PAYMENT_ORDER_COST_NOT_CONFIGURED':
        'payment_orders.errors.cost_not_configured',
    'FIELD_PAYMENT_ORDER_CYCLE_INVALID':
        'payment_orders.errors.cycle_invalid',
    'FIELD_PAYMENT_ORDER_CAMPOREE_INVALID':
        'payment_orders.errors.camporee_invalid',
    'FIELD_PAYMENT_ORDER_ELIGIBILITY_FAILED':
        'payment_orders.errors.eligibility_failed',
    'FIELD_PAYMENT_ORDER_LEGACY_DISABLED':
        'payment_orders.errors.legacy_disabled',
    'FIELD_PAYMENT_ORDER_PROOF_INVALID_FILE':
        'payment_orders.errors.proof_invalid_file',
    'FIELD_PAYMENT_ORDER_FORBIDDEN': 'payment_orders.errors.forbidden',
    'FIELD_PAYMENT_ORDER_NOT_FOUND': 'payment_orders.errors.not_found',
    'INSURANCE_REASSIGNMENT_INVALID':
        'payment_orders.errors.reassignment_invalid',
    'INSURANCE_REASSIGNMENT_PENDING_EXISTS':
        'payment_orders.errors.reassignment_pending_exists',
  };

  String? _extractDioCode(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) return data['code']?.toString();
    } catch (_) {
      // Cuerpo no parseable — se cae al mensaje genérico.
    }
    return null;
  }

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
      final businessCode = _extractDioCode(e);
      final i18nKey =
          businessCode != null ? _businessErrorKeys[businessCode] : null;
      if (i18nKey != null) {
        throw ServerException(
          message: tr(i18nKey),
          code: e.response?.statusCode,
        );
      }
      throw ServerException(
        message: _extractDioMessage(e),
        code: e.response?.statusCode,
      );
    }
    if (e is ServerException || e is AuthException) throw e;
    throw ServerException(message: e.toString());
  }

  String _extractDioMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        return (data['message'] ?? e.message ?? tr('common.error_network'))
            .toString();
      }
    } catch (_) {
      // Ignorado: mensaje genérico abajo.
    }
    return e.message ?? tr('common.error_network');
  }
}
