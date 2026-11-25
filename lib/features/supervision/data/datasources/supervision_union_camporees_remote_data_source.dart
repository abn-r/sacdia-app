import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/errors/authorization_stale.dart';
import '../../../../core/errors/business_error.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/supervision_union_camporee.dart';
import '../models/supervision_union_camporee_model.dart';

abstract class SupervisionUnionCamporeesRemoteDataSource {
  /// GET /camporees/union?active=true&page=1&limit=100
  Future<List<SupervisionUnionCamporee>> getCamporees({
    CancelToken? cancelToken,
  });

  /// GET /camporees/union/:camporeeId
  Future<SupervisionUnionCamporee> getCamporee(
    int camporeeId, {
    CancelToken? cancelToken,
  });

  /// `/pending` and `/clubs?status=pending_approval` in parallel. Club rows
  /// come from the second one (it has names); if it fails for a reason other
  /// than cancellation or a stale authorization, the `/pending` clubs are used
  /// with empty names. A failure of `/pending` fails the call.
  Future<SupervisionCamporeePending> getPending(
    int camporeeId, {
    CancelToken? cancelToken,
  });

  /// PATCH /camporees/union/:camporeeId/clubs/:camporeeClubId/(approve|reject)
  Future<void> decideClub(
    int camporeeId,
    int camporeeClubId, {
    required bool approve,
    String? reason,
  });

  /// PATCH /camporees/union/:camporeeId/members/:camporeeMemberId/(approve|reject)
  Future<void> decideMember(
    int camporeeId,
    int camporeeMemberId, {
    required bool approve,
    String? reason,
  });

  /// PATCH /camporees/payments/:paymentId/(approve|reject)
  Future<void> decidePayment(
    String paymentId, {
    required bool approve,
    String? reason,
  });
}

class SupervisionUnionCamporeesRemoteDataSourceImpl
    implements SupervisionUnionCamporeesRemoteDataSource {
  final Dio _dio;
  final String _baseUrl;

  static const _tag = 'SupervisionUnionCamporeesDS';

  SupervisionUnionCamporeesRemoteDataSourceImpl({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  String get _root => '$_baseUrl${ApiEndpoints.camporees}';

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

  /// `rejection_reason` only when non-blank; approve sends no body.
  Map<String, dynamic>? _body({required bool approve, String? reason}) {
    if (approve) return null;
    final trimmed = reason?.trim() ?? '';
    return {if (trimmed.isNotEmpty) 'rejection_reason': trimmed};
  }

  Future<void> _decide(
    String path, {
    required bool approve,
    String? reason,
    required String label,
  }) async {
    try {
      final body = _body(approve: approve, reason: reason);
      final response = await _dio.patch(
        path,
        data: (body == null || body.isEmpty) ? null : body,
      );
      _expectOk(response);
    } catch (e) {
      AppLogger.e('Error en $label (supervision union camporees)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<List<SupervisionUnionCamporee>> getCamporees({
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_root/union',
        queryParameters: {'active': true, 'page': 1, 'limit': 100},
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      return SupervisionUnionCamporeeModel.parseList(response.data);
    } catch (e) {
      AppLogger.e('Error en getCamporees (supervision union camporees)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<SupervisionUnionCamporee> getCamporee(
    int camporeeId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_root/union/$camporeeId',
        cancelToken: cancelToken,
      );
      if (_isOk(response.statusCode)) {
        final data = response.data;
        final item = SupervisionUnionCamporeeModel.tryParse(
          data is Map && data['union_camporee_id'] == null
              ? _unwrap(data)
              : data,
        );
        if (item != null) return item;
      }
      _badResponse(response);
    } catch (e) {
      AppLogger.e('Error en getCamporee (supervision union camporees)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  /// Raw call: errors are classified by the caller.
  Future<List<SupervisionCamporeePendingClub>> _fetchClubsWithNames(
    int camporeeId,
    CancelToken? cancelToken,
  ) async {
    final response = await _dio.get(
      '$_root/union/$camporeeId/clubs',
      queryParameters: {'status': 'pending_approval'},
      cancelToken: cancelToken,
    );
    if (!_isOk(response.statusCode)) _badResponse(response);
    return SupervisionUnionCamporeeModel.parseClubsWithNames(response.data);
  }

  @override
  Future<SupervisionCamporeePending> getPending(
    int camporeeId, {
    CancelToken? cancelToken,
  }) async {
    // Start both; the club-names request is captured so it never leaks an
    // unhandled error when `/pending` fails first.
    final Future<Object> clubsOutcome =
        _fetchClubsWithNames(camporeeId, cancelToken).then<Object>(
      (clubs) => clubs,
      onError: (Object e, StackTrace _) => e,
    );
    try {
      final response = await _dio.get(
        '$_root/union/$camporeeId/pending',
        cancelToken: cancelToken,
      );
      if (!_isOk(response.statusCode)) _badResponse(response);
      final pending = SupervisionUnionCamporeeModel.parsePending(response.data);
      final outcome = await clubsOutcome;
      if (outcome is List<SupervisionCamporeePendingClub>) {
        return SupervisionCamporeePending(
          clubs: outcome,
          members: pending.members,
          payments: pending.payments,
        );
      }
      if (outcome is DioException &&
          (outcome.type == DioExceptionType.cancel ||
              isAuthorizationStale(outcome))) {
        _rethrow(outcome);
      }
      AppLogger.e('Club names unavailable, using /pending clubs',
          tag: _tag, error: outcome);
      return pending;
    } catch (e) {
      AppLogger.e('Error en getPending (supervision union camporees)',
          tag: _tag, error: e);
      _rethrow(e);
    }
  }

  @override
  Future<void> decideClub(
    int camporeeId,
    int camporeeClubId, {
    required bool approve,
    String? reason,
  }) =>
      _decide(
        '$_root/union/$camporeeId/clubs/$camporeeClubId/'
        '${approve ? 'approve' : 'reject'}',
        approve: approve,
        reason: reason,
        label: 'decideClub',
      );

  @override
  Future<void> decideMember(
    int camporeeId,
    int camporeeMemberId, {
    required bool approve,
    String? reason,
  }) =>
      _decide(
        '$_root/union/$camporeeId/members/$camporeeMemberId/'
        '${approve ? 'approve' : 'reject'}',
        approve: approve,
        reason: reason,
        label: 'decideMember',
      );

  @override
  Future<void> decidePayment(
    String paymentId, {
    required bool approve,
    String? reason,
  }) =>
      _decide(
        '$_root/payments/$paymentId/${approve ? 'approve' : 'reject'}',
        approve: approve,
        reason: reason,
        label: 'decidePayment',
      );
}
