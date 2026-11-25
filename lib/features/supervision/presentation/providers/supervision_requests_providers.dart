import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_requests_remote_data_source.dart';
import '../../data/repositories/supervision_requests_repository_impl.dart';
import '../../domain/entities/supervision_request.dart';
import '../../domain/repositories/supervision_requests_repository.dart';
import 'supervision_providers.dart';

final supervisionRequestsRemoteDataSourceProvider =
    Provider<SupervisionRequestsRemoteDataSource>((ref) {
  return SupervisionRequestsRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionRequestsRepositoryProvider =
    Provider<SupervisionRequestsRepository>((ref) {
  return SupervisionRequestsRepositoryImpl(
    remoteDataSource: ref.read(supervisionRequestsRemoteDataSourceProvider),
  );
});

class SupervisionRequestsQuery extends Equatable {
  const SupervisionRequestsQuery({required this.kind, required this.status});

  final SupervisionRequestKind kind;
  final SupervisionRequestStatus status;

  @override
  List<Object?> get props => [kind, status];
}

/// Requests of one kind filtered by status.
final supervisionRequestsProvider = FutureProvider.autoDispose
    .family<List<SupervisionRequest>, SupervisionRequestsQuery>(
        (ref, query) async {
  final repository = ref.read(supervisionRequestsRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getRequests(
    kind: query.kind,
    status: query.status,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (items) => items,
  );
});

class SupervisionRequestReviewResult {
  const SupervisionRequestReviewResult({
    this.request,
    this.errorMessage,
    this.errorCode,
  });

  final SupervisionRequest? request;
  final String? errorMessage;
  final String? errorCode;

  bool get ok => request != null && errorMessage == null;
}

/// Approves or rejects a request. Stateless: safe to `ref.read` from a view.
class SupervisionRequestReviewer {
  const SupervisionRequestReviewer(this._ref);

  final Ref _ref;

  static const _staleCodes = {
    'REQUEST_TRANSFER_ALREADY_REVIEWED',
    'REQUEST_ASSIGNMENT_ALREADY_REVIEWED',
    'REQUEST_TRANSFER_NOT_FOUND',
    'REQUEST_ASSIGNMENT_NOT_FOUND',
  };

  Future<SupervisionRequestReviewResult> review(
    SupervisionRequest request, {
    required bool approve,
    String? comment,
  }) =>
      _ref.keepAliveDuring(() async {
        final repository = _ref.read(supervisionRequestsRepositoryProvider);
        final trimmed = comment?.trim();
        final result = await repository.review(
          kind: request.kind,
          requestId: request.id,
          approve: approve,
          comment: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        );
        return result.fold(
          (failure) {
            if (_staleCodes.contains(failure.errorCode)) {
              _ref.invalidate(supervisionRequestsProvider);
            }
            return SupervisionRequestReviewResult(
              errorMessage: failure.message,
              errorCode: failure.errorCode,
            );
          },
          (updated) {
            _ref.invalidate(supervisionRequestsProvider);
            _ref.invalidate(supervisionPendingCountsProvider);
            return SupervisionRequestReviewResult(
              request: updated.fillMissingFrom(request),
            );
          },
        );
      });
}

final supervisionRequestReviewerProvider =
    Provider.autoDispose<SupervisionRequestReviewer>(
  (ref) => SupervisionRequestReviewer(ref),
);
