import 'package:dartz/dartz.dart' show Either, Unit;
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/providers/keep_alive_during.dart';
import '../../../auth/presentation/providers/auth_providers.dart'
    show apiBaseUrlProvider;
import '../../../../providers/dio_provider.dart';
import '../../data/datasources/supervision_union_camporees_remote_data_source.dart';
import '../../data/repositories/supervision_union_camporees_repository_impl.dart';
import '../../domain/entities/supervision_union_camporee.dart';
import '../../domain/repositories/supervision_union_camporees_repository.dart';
import 'supervision_action_result.dart';
import 'supervision_providers.dart';

/// Codes meaning the item was already decided or is gone: the list is stale.
const Set<String> _stalePendingCodes = {
  'CAMPOREE_CLUB_ENROLLMENT_PENDING_NOT_FOUND',
  'CAMPOREE_MEMBER_ENROLLMENT_PENDING_NOT_FOUND',
  'CAMPOREE_PAYMENT_PENDING_NOT_FOUND',
};

final supervisionUnionCamporeesRemoteDataSourceProvider =
    Provider<SupervisionUnionCamporeesRemoteDataSource>((ref) {
  return SupervisionUnionCamporeesRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final supervisionUnionCamporeesRepositoryProvider =
    Provider<SupervisionUnionCamporeesRepository>((ref) {
  return SupervisionUnionCamporeesRepositoryImpl(
    remoteDataSource:
        ref.read(supervisionUnionCamporeesRemoteDataSourceProvider),
  );
});

/// Active camporees of the actor's union.
final supervisionUnionCamporeesProvider =
    FutureProvider.autoDispose<List<SupervisionUnionCamporee>>((ref) async {
  final repository = ref.read(supervisionUnionCamporeesRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repository.getCamporees(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (items) => items,
  );
});

final supervisionUnionCamporeeProvider = FutureProvider.autoDispose
    .family<SupervisionUnionCamporee, int>((ref, camporeeId) async {
  final repository = ref.read(supervisionUnionCamporeesRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result =
      await repository.getCamporee(camporeeId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (item) => item,
  );
});

/// Clubs, members and payments waiting for a decision.
final supervisionCamporeePendingProvider = FutureProvider.autoDispose
    .family<SupervisionCamporeePending, int>((ref, camporeeId) async {
  final repository = ref.read(supervisionUnionCamporeesRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result =
      await repository.getPending(camporeeId, cancelToken: cancelToken);
  return result.fold(
    (failure) => throw SupervisionLoadException.fromFailure(failure),
    (pending) => pending,
  );
});

/// Approve / reject actions. Stateless: safe to `ref.read` from a view.
class SupervisionCamporeeApprovalActions {
  const SupervisionCamporeeApprovalActions(this._ref);

  final Ref _ref;

  String? _cleanReason(String? reason) {
    final trimmed = reason?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  Future<SupervisionActionResult> decideClub(
    int camporeeId,
    int id, {
    required bool approve,
    String? reason,
  }) =>
      _run(
        camporeeId,
        (repo) => repo.decideClub(
          camporeeId,
          id,
          approve: approve,
          reason: _cleanReason(reason),
        ),
      );

  Future<SupervisionActionResult> decideMember(
    int camporeeId,
    int id, {
    required bool approve,
    String? reason,
  }) =>
      _run(
        camporeeId,
        (repo) => repo.decideMember(
          camporeeId,
          id,
          approve: approve,
          reason: _cleanReason(reason),
        ),
      );

  Future<SupervisionActionResult> decidePayment(
    int camporeeId,
    String paymentId, {
    required bool approve,
    String? reason,
  }) =>
      _run(
        camporeeId,
        (repo) => repo.decidePayment(
          paymentId,
          approve: approve,
          reason: _cleanReason(reason),
        ),
      );

  Future<SupervisionActionResult> _run(
    int camporeeId,
    Future<Either<Failure, Unit>> Function(
            SupervisionUnionCamporeesRepository repo)
        call,
  ) =>
      _ref.keepAliveDuring(() async {
        final repository =
            _ref.read(supervisionUnionCamporeesRepositoryProvider);
        final result = await call(repository);
        return result.fold(
          (failure) {
            if (_stalePendingCodes.contains(failure.errorCode)) {
              _invalidate(camporeeId);
            }
            return SupervisionActionResult.fromFailure(failure);
          },
          (_) {
            _invalidate(camporeeId);
            return const SupervisionActionResult.success();
          },
        );
      });

  void _invalidate(int camporeeId) {
    _ref.invalidate(supervisionCamporeePendingProvider(camporeeId));
    _ref.invalidate(supervisionPendingCountsProvider);
  }
}

final supervisionCamporeeApprovalActionsProvider =
    Provider<SupervisionCamporeeApprovalActions>(
  (ref) => SupervisionCamporeeApprovalActions(ref),
);
