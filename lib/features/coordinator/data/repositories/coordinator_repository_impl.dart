import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/sla_dashboard.dart';
import '../../domain/entities/evidence_review_item.dart';
import '../../domain/entities/camporee_approval.dart';
import '../../domain/repositories/coordinator_repository.dart';
import '../datasources/coordinator_remote_data_source.dart';

/// Implementación del repositorio del coordinador.
class CoordinatorRepositoryImpl implements CoordinatorRepository {
  final CoordinatorRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CoordinatorRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Helpers ───────────────────────────────────────────────────────────────────

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── SLA Dashboard ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, SlaDashboard>> getSlaDashboard({
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getSlaDashboard(
        cancelToken: cancelToken,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Evidence Review ───────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<EvidenceReviewItem>>> getPendingEvidence({
    int page = 1,
    int limit = 20,
    EvidenceReviewType? type,
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getPendingEvidence(
        page: page,
        limit: limit,
        type: type,
        cancelToken: cancelToken,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, EvidenceReviewItem>> getEvidenceDetail({
    required EvidenceReviewType type,
    required String id,
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getEvidenceDetail(
        type: type,
        id: id,
        cancelToken: cancelToken,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> approveEvidence({
    required EvidenceReviewType type,
    required String id,
    String? comment,
  }) async {
    try {
      await remoteDataSource.approveEvidence(
        type: type,
        id: id,
        comment: comment,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> rejectEvidence({
    required EvidenceReviewType type,
    required String id,
    required String rejectionReason,
  }) async {
    try {
      await remoteDataSource.rejectEvidence(
        type: type,
        id: id,
        rejectionReason: rejectionReason,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> bulkApproveEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
  }) async {
    try {
      await remoteDataSource.bulkApproveEvidence(ids: ids, type: type);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> bulkRejectEvidence({
    required List<String> ids,
    required EvidenceReviewType type,
    required String rejectionReason,
  }) async {
    try {
      await remoteDataSource.bulkRejectEvidence(
        ids: ids,
        type: type,
        rejectionReason: rejectionReason,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Camporee list ─────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<CamporeeItem>>> listLocalCamporees({
    bool activeOnly = true,
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.listLocalCamporees(
        activeOnly: activeOnly,
        cancelToken: cancelToken,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeeItem>>> listUnionCamporees({
    CancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.listUnionCamporees(
        cancelToken: cancelToken,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Camporee pending approvals ────────────────────────────────────────────────

  @override
  Future<Either<Failure, CamporeePendingApprovals>> getLocalCamporeePending(
    int camporeeId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getLocalCamporeePending(
        camporeeId,
        cancelToken: cancelToken,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CamporeePendingApprovals>> getUnionCamporeePending(
    int camporeeId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getUnionCamporeePending(
        camporeeId,
        cancelToken: cancelToken,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Club enrollment approve/reject ────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> approveCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
  }) async {
    try {
      await remoteDataSource.approveCamporeeClub(
        camporeeId: camporeeId,
        camporeeClubId: camporeeClubId,
        scope: scope,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> rejectCamporeeClub({
    required int camporeeId,
    required int camporeeClubId,
    required CamporeeScope scope,
    String? rejectionReason,
  }) async {
    try {
      await remoteDataSource.rejectCamporeeClub(
        camporeeId: camporeeId,
        camporeeClubId: camporeeClubId,
        scope: scope,
        rejectionReason: rejectionReason,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Member enrollment approve/reject ──────────────────────────────────────────

  @override
  Future<Either<Failure, void>> approveCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
  }) async {
    try {
      await remoteDataSource.approveCamporeeMember(
        camporeeId: camporeeId,
        camporeeMemberId: camporeeMemberId,
        scope: scope,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> rejectCamporeeMember({
    required int camporeeId,
    required int camporeeMemberId,
    required CamporeeScope scope,
    String? rejectionReason,
  }) async {
    try {
      await remoteDataSource.rejectCamporeeMember(
        camporeeId: camporeeId,
        camporeeMemberId: camporeeMemberId,
        scope: scope,
        rejectionReason: rejectionReason,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Payment approve/reject ────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> approveCamporeePayment({
    required String camporeePaymentId,
  }) async {
    try {
      await remoteDataSource.approveCamporeePayment(
        camporeePaymentId: camporeePaymentId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> rejectCamporeePayment({
    required String camporeePaymentId,
    String? rejectionReason,
  }) async {
    try {
      await remoteDataSource.rejectCamporeePayment(
        camporeePaymentId: camporeePaymentId,
        rejectionReason: rejectionReason,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
