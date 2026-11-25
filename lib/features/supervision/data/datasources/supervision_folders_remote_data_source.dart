import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/supervision_folder.dart';
import '../models/supervision_folder_model.dart';

abstract class SupervisionFoldersRemoteDataSource {
  /// GET /annual-folders/evaluation/queue
  Future<SupervisionFolderQueuePage> getQueue({
    SupervisionFolderQueueFilter filter =
        SupervisionFolderQueueFilter.needsReview,
    int page = 1,
    int limit = 25,
    CancelToken? cancelToken,
  });

  /// GET /annual-folders/:folderId
  Future<SupervisionFolderDetail> getFolder(
    String folderId, {
    CancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/sections/:sectionId/evaluate
  Future<void> evaluateSection(
    String folderId,
    String sectionId, {
    required int earnedPoints,
    String? notes,
    CancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/sections/:sectionId/reopen
  Future<void> reopenSection(
    String folderId,
    String sectionId, {
    CancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/sections/:sectionId/confirm-union
  Future<void> confirmUnion(
    String folderId,
    String sectionId, {
    required bool approve,
    String? notes,
    CancelToken? cancelToken,
  });

  /// POST /annual-folders/:folderId/close
  Future<void> closeFolder(
    String folderId, {
    CancelToken? cancelToken,
  });

  /// PATCH /annual-folders/evidences/:evidenceId/reviewer-note
  Future<void> saveReviewerNote(
    String evidenceId,
    String? note, {
    CancelToken? cancelToken,
  });
}

class SupervisionFoldersRemoteDataSourceImpl
    implements SupervisionFoldersRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionFoldersDS';

  SupervisionFoldersRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String get _root => '$_baseUrl${ApiEndpoints.annualFolders}';

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

  Object? _unwrap(Object? raw) =>
      raw is Map && raw.containsKey('data') ? raw['data'] : raw;

  Never _badResponse(Response<dynamic> response) => throw ServerException(
        message: tr('common.error_network'),
        code: response.statusCode,
      );

  void _expectOk(Response<dynamic> response) {
    if (!_isOk(response.statusCode)) _badResponse(response);
  }

  Map<String, dynamic> _notesBody(String? notes) {
    final trimmed = notes?.trim() ?? '';
    return {if (trimmed.isNotEmpty) 'notes': trimmed};
  }

  @override
  Future<SupervisionFolderQueuePage> getQueue({
    SupervisionFolderQueueFilter filter =
        SupervisionFolderQueueFilter.needsReview,
    int page = 1,
    int limit = 25,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_root/evaluation/queue',
        queryParameters: {
          'status': filter.apiValue,
          'page': page,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionFolderModel.parseQueuePage(_unwrap(response.data));
    } catch (e) {
      AppLogger.e('Error en getQueue (supervision folders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionFolderDetail> getFolder(
    String folderId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_root/$folderId',
        cancelToken: cancelToken,
      );
      if (_isOk(response.statusCode)) {
        final detail =
            SupervisionFolderModel.tryParseDetail(_unwrap(response.data));
        if (detail != null) return detail;
      }
      _badResponse(response);
    } catch (e) {
      AppLogger.e('Error en getFolder (supervision folders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<void> evaluateSection(
    String folderId,
    String sectionId, {
    required int earnedPoints,
    String? notes,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '$_root/$folderId/sections/$sectionId/evaluate',
        data: {'earned_points': earnedPoints, ..._notesBody(notes)},
        cancelToken: cancelToken,
      );
      _expectOk(response);
    } catch (e) {
      AppLogger.e('Error en evaluateSection (supervision folders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<void> reopenSection(
    String folderId,
    String sectionId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '$_root/$folderId/sections/$sectionId/reopen',
        cancelToken: cancelToken,
      );
      _expectOk(response);
    } catch (e) {
      AppLogger.e('Error en reopenSection (supervision folders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<void> confirmUnion(
    String folderId,
    String sectionId, {
    required bool approve,
    String? notes,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '$_root/$folderId/sections/$sectionId/confirm-union',
        data: {
          'decision': approve ? 'APPROVED' : 'REJECTED_OVERRIDE',
          ..._notesBody(notes),
        },
        cancelToken: cancelToken,
      );
      _expectOk(response);
    } catch (e) {
      AppLogger.e('Error en confirmUnion (supervision folders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<void> closeFolder(
    String folderId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.post(
        '$_root/$folderId/close',
        cancelToken: cancelToken,
      );
      _expectOk(response);
    } catch (e) {
      AppLogger.e('Error en closeFolder (supervision folders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<void> saveReviewerNote(
    String evidenceId,
    String? note, {
    CancelToken? cancelToken,
  }) async {
    try {
      final trimmed = note?.trim() ?? '';
      final response = await _dio.patch(
        '$_root/evidences/$evidenceId/reviewer-note',
        data: {'reviewer_note': trimmed.isEmpty ? null : trimmed},
        cancelToken: cancelToken,
      );
      _expectOk(response);
    } catch (e) {
      AppLogger.e('Error en saveReviewerNote (supervision folders)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }
}
