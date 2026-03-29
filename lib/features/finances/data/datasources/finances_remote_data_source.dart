import 'package:dio/dio.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/finance_category_model.dart';
import '../models/finance_month_model.dart';
import '../models/finance_summary_model.dart';
import '../models/transaction_model.dart';

abstract class FinancesRemoteDataSource {
  Future<FinanceMonthModel> getFinances({
    required int clubId,
    required int year,
    required int month,
  });

  Future<FinanceSummaryModel> getSummary({required int clubId});

  Future<FinanceTransactionModel> getTransaction({required int financeId});

  Future<FinanceTransactionModel> createTransaction({
    required int clubId,
    required int categoryId,
    required double amount,
    required String description,
    required DateTime date,
    required int year,
    required int month,
    String? notes,
  });

  Future<FinanceTransactionModel> updateTransaction({
    required int financeId,
    int? categoryId,
    double? amount,
    String? description,
    DateTime? date,
    String? notes,
  });

  Future<void> deleteTransaction({required int financeId});

  Future<List<FinanceCategoryModel>> getCategories();
}

class FinancesRemoteDataSourceImpl implements FinancesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'FinancesDS';

  FinancesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  // ── GET /clubs/:clubId/finances?year=&month= ──────────────────────────────

  @override
  Future<FinanceMonthModel> getFinances({
    required int clubId,
    required int year,
    required int month,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances',
        queryParameters: {'year': year, 'month': month},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final json = body is Map<String, dynamic> ? body : {'data': body};
        return FinanceMonthModel.fromJson(json, year: year, month: month);
      }

      throw ServerException(
        message: 'Error al obtener movimientos financieros',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getFinances', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/finances/summary ───────────────────────────────────

  @override
  Future<FinanceSummaryModel> getSummary({required int clubId}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances/summary',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json =
            body.containsKey('data') ? body['data'] as Map<String, dynamic> : body;
        return FinanceSummaryModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al obtener el resumen financiero',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getSummary', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /finances/:financeId ──────────────────────────────────────────────

  @override
  Future<FinanceTransactionModel> getTransaction(
      {required int financeId}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.finances}/$financeId',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json =
            body.containsKey('data') ? body['data'] as Map<String, dynamic> : body;
        return FinanceTransactionModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al obtener el movimiento',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getTransaction', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /clubs/:clubId/finances ──────────────────────────────────────────

  @override
  Future<FinanceTransactionModel> createTransaction({
    required int clubId,
    required int categoryId,
    required double amount,
    required String description,
    required DateTime date,
    required int year,
    required int month,
    String? notes,
  }) async {
    try {
      final body = {
        'finance_category_id': categoryId,
        'amount': amount.toInt(),
        'description': description,
        'finance_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'year': year,
        'month': month,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      };

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resp = response.data as Map<String, dynamic>;
        final json =
            resp.containsKey('data') ? resp['data'] as Map<String, dynamic> : resp;
        return FinanceTransactionModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al crear el movimiento',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en createTransaction', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── PATCH /finances/:financeId ────────────────────────────────────────────

  @override
  Future<FinanceTransactionModel> updateTransaction({
    required int financeId,
    int? categoryId,
    double? amount,
    String? description,
    DateTime? date,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        if (categoryId != null) 'finance_category_id': categoryId,
        if (amount != null) 'amount': amount.toInt(),
        if (description != null) 'description': description,
        if (date != null)
          'finance_date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        if (notes != null) 'notes': notes,
      };

      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.finances}/$financeId',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resp = response.data as Map<String, dynamic>;
        final json =
            resp.containsKey('data') ? resp['data'] as Map<String, dynamic> : resp;
        return FinanceTransactionModel.fromJson(json);
      }

      throw ServerException(
        message: 'Error al actualizar el movimiento',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en updateTransaction', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── DELETE /finances/:financeId ───────────────────────────────────────────

  @override
  Future<void> deleteTransaction({required int financeId}) async {
    try {
      final response = await _dio.delete(
        '$_baseUrl${ApiEndpoints.finances}/$financeId',
      );

      if (response.statusCode == 200 ||
          response.statusCode == 201 ||
          response.statusCode == 204) {
        return;
      }

      throw ServerException(
        message: 'Error al eliminar el movimiento',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en deleteTransaction', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /finances/categories ──────────────────────────────────────────────

  @override
  Future<List<FinanceCategoryModel>> getCategories() async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.finances}/categories',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final List<dynamic> rawList = body is List
            ? body
            : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        return rawList
            .map((e) =>
                FinanceCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: 'Error al obtener categorías',
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getCategories', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Error helper ──────────────────────────────────────────────────────────

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
        return (data['message'] ?? e.message ?? 'Error de conexión').toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? 'Error de conexión';
  }
}
