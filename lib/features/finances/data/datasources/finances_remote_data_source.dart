import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/category_breakdown_model.dart';
import '../models/finance_category_model.dart';
import '../models/finance_export_file_model.dart';
import '../models/finance_month_model.dart';
import '../models/finance_monthly_series_model.dart';
import '../models/finance_summary_model.dart';
import '../models/paginated_transactions_response.dart';
import '../../domain/entities/finance_export.dart';
import '../../domain/entities/paginated_transactions_response.dart';
import '../models/transaction_model.dart';

abstract class FinancesRemoteDataSource {
  Future<FinanceMonthModel> getFinances({
    required int clubId,
    required int year,
    required int month,
    CancelToken? cancelToken,
  });

  Future<FinanceSummaryModel> getSummary({
    required int clubId,
    int? year,
    int? month,
    CancelToken? cancelToken,
  });

  /// Totales por categoría de un mes (o del año completo si [month] es null).
  Future<CategoryBreakdownModel> getByCategory({
    required int clubId,
    required int year,
    int? month,
    CancelToken? cancelToken,
  });

  /// Serie mensual (`GET /clubs/:clubId/finances/monthly`). Sin [fromYear] y
  /// [fromMonth] el servidor arranca en el primer movimiento del club.
  Future<FinanceMonthlySeriesModel> getMonthlySeries({
    required int clubId,
    int? fromYear,
    int? fromMonth,
    required int toYear,
    required int toMonth,
    CancelToken? cancelToken,
  });

  /// Descarga el mes en [format] (`GET /clubs/:clubId/finances/export`).
  ///
  /// El alcance por sección lo resuelve el servidor, igual que en el listado.
  Future<FinanceExportFileModel> exportFinances({
    required int clubId,
    required int year,
    required int month,
    required FinanceExportFormat format,
    CancelToken? cancelToken,
  });

  Future<FinanceTransactionModel> getTransaction({
    required int financeId,
    CancelToken? cancelToken,
  });

  Future<FinanceTransactionModel> createTransaction({
    required int clubId,
    required int categoryId,
    required double amount,
    required String description,
    required DateTime date,
    required int year,
    required int month,
    required int clubSectionId,
    required int clubTypeId,
  });

  Future<FinanceTransactionModel> updateTransaction({
    required int financeId,
    int? categoryId,
    double? amount,
    String? description,
    DateTime? date,
  });

  Future<FinanceEvidenceModel> uploadEvidence({
    required int financeId,
    required String filePath,
    required String fileName,
    required String mimeType,
  });

  Future<void> deleteTransaction({required int financeId});

  Future<List<FinanceCategoryModel>> getCategories({
    CancelToken? cancelToken,
  });

  /// Paginated, filterable, sortable transaction list.
  ///
  /// Backs the "All Transactions" screen.
  Future<PaginatedTransactionsResponse> getTransactionsPaginated({
    required int clubId,
    required int page,
    required int limit,
    String? type,
    String? search,
    String? startDate,
    String? endDate,
    String? sortBy,
    String? sortOrder,
    CancelToken? cancelToken,
  });
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
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances',
        queryParameters: {'year': year, 'month': month},
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final json = body is Map<String, dynamic> ? body : {'data': body};
        return FinanceMonthModel.fromJson(json, year: year, month: month);
      }

      throw ServerException(
        message: tr('finances.errors.fetch_finances'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getFinances', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/finances/summary ───────────────────────────────────

  @override
  Future<FinanceSummaryModel> getSummary({
    required int clubId,
    int? year,
    int? month,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances/summary',
        queryParameters: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return FinanceSummaryModel.fromJson(json);
      }

      throw ServerException(
        message: tr('finances.errors.fetch_summary'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getSummary', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/finances/monthly ───────────────────────────────────

  @override
  Future<FinanceMonthlySeriesModel> getMonthlySeries({
    required int clubId,
    int? fromYear,
    int? fromMonth,
    required int toYear,
    required int toMonth,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances/monthly',
        queryParameters: {
          if (fromYear != null && fromMonth != null)
            'from': _yearMonth(fromYear, fromMonth),
          'to': _yearMonth(toYear, toMonth),
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return FinanceMonthlySeriesModel.fromJson(json);
      }

      throw ServerException(
        message: tr('finances.errors.fetch_monthly_series'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getMonthlySeries', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  static String _yearMonth(int year, int month) =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';

  // ── GET /clubs/:clubId/finances/by-category ───────────────────────────────

  @override
  Future<CategoryBreakdownModel> getByCategory({
    required int clubId,
    required int year,
    int? month,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances/by-category',
        queryParameters: {
          'year': year,
          if (month != null) 'month': month,
        },
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return CategoryBreakdownModel.fromJson(json);
      }

      throw ServerException(
        message: tr('finances.errors.fetch_by_category'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getByCategory', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/finances/export?format= ────────────────────────────

  @override
  Future<FinanceExportFileModel> exportFinances({
    required int clubId,
    required int year,
    required int month,
    required FinanceExportFormat format,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances/export',
        queryParameters: {
          'year': year,
          'month': month,
          'format': format.apiValue,
        },
        options: Options(responseType: ResponseType.bytes),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (response.statusCode == 200 && data != null && data.isNotEmpty) {
        return FinanceExportFileModel(
          bytes: Uint8List.fromList(data),
          fileName: FinanceExportFileModel.resolveFileName(
            response.headers.value('content-disposition'),
            year: year,
            month: month,
            format: format,
          ),
        );
      }

      throw ServerException(
        message: tr('finances.errors.export'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en exportFinances', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /finances/:financeId ──────────────────────────────────────────────

  @override
  Future<FinanceTransactionModel> getTransaction({
    required int financeId,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.finances}/$financeId',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return FinanceTransactionModel.fromJson(json);
      }

      throw ServerException(
        message: tr('finances.errors.fetch_transaction'),
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
    required int clubSectionId,
    required int clubTypeId,
  }) async {
    try {
      final body = {
        'finance_category_id': categoryId,
        'amount': amount.toInt(),
        'description': description,
        'finance_date':
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'year': year,
        'month': month,
        'club_section_id': clubSectionId,
        'club_type_id': clubTypeId,
      };

      final response = await _dio.post(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId/finances',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resp = response.data as Map<String, dynamic>;
        final json = resp.containsKey('data')
            ? resp['data'] as Map<String, dynamic>
            : resp;
        return FinanceTransactionModel.fromJson(json);
      }

      throw ServerException(
        message: tr('finances.errors.create'),
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
  }) async {
    try {
      final body = <String, dynamic>{
        if (categoryId != null) 'finance_category_id': categoryId,
        if (amount != null) 'amount': amount.toInt(),
        if (description != null) 'description': description,
        if (date != null)
          'finance_date':
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      };

      final response = await _dio.patch(
        '$_baseUrl${ApiEndpoints.finances}/$financeId',
        data: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final resp = response.data as Map<String, dynamic>;
        final json = resp.containsKey('data')
            ? resp['data'] as Map<String, dynamic>
            : resp;
        return FinanceTransactionModel.fromJson(json);
      }

      throw ServerException(
        message: tr('finances.errors.update'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en updateTransaction', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── POST /finances/:financeId/evidences ──────────────────────────────────

  @override
  Future<FinanceEvidenceModel> uploadEvidence({
    required int financeId,
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
        '$_baseUrl${ApiEndpoints.finances}/$financeId/evidences',
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        final json = body.containsKey('data')
            ? body['data'] as Map<String, dynamic>
            : body;
        return FinanceEvidenceModel.fromJson(json);
      }

      throw ServerException(
        message: tr('finances.errors.upload_evidence'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en uploadEvidence', tag: _tag, error: e);
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
        message: tr('finances.errors.delete'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en deleteTransaction', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /finances/categories ──────────────────────────────────────────────

  @override
  Future<List<FinanceCategoryModel>> getCategories({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.finances}/categories',
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data;
        final List<dynamic> rawList = body is List
            ? body
            : (body as Map<String, dynamic>)['data'] as List<dynamic>? ?? [];
        return rawList
            .map(
                (e) => FinanceCategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      throw ServerException(
        message: tr('finances.errors.fetch_categories'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getCategories', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── GET /clubs/:clubId/finances/transactions ─────────────────────────────

  @override
  Future<PaginatedTransactionsResponse> getTransactionsPaginated({
    required int clubId,
    required int page,
    required int limit,
    String? type,
    String? search,
    String? startDate,
    String? endDate,
    String? sortBy,
    String? sortOrder,
    CancelToken? cancelToken,
  }) async {
    try {
      final params = <String, dynamic>{
        'page': page,
        'limit': limit,
        if (type != null && type.isNotEmpty) 'type': type,
        if (search != null && search.isNotEmpty) 'search': search,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      };

      final response = await _dio.get(
        '$_baseUrl${ApiEndpoints.clubs}/$clubId${ApiEndpoints.finances}/transactions',
        queryParameters: params,
        cancelToken: cancelToken,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = response.data as Map<String, dynamic>;
        return parsePaginatedTransactionsResponse(body);
      }

      throw ServerException(
        message: tr('finances.errors.fetch_paginated'),
        code: response.statusCode,
      );
    } catch (e) {
      AppLogger.e('Error en getTransactionsPaginated', tag: _tag, error: e);
      _rethrow(e);
    }
  }

  // ── Error helper ──────────────────────────────────────────────────────────

  Never _rethrow(Object e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.cancel) throw e;
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
        return (data['message'] ?? e.message ?? tr('common.error_network'))
            .toString();
      }
    } catch (e) {
      AppLogger.w('Error al parsear respuesta de error', tag: _tag, error: e);
    }
    return e.message ?? tr('common.error_network');
  }
}
