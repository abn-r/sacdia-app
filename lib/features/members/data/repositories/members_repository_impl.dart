import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../domain/entities/annual_continuation.dart';
import '../../domain/entities/assignable_role.dart';
import '../../domain/entities/claim_code.dart';
import '../../domain/entities/club_member.dart';
import '../../domain/entities/consent_verification_result.dart';
import '../../domain/entities/create_minor.dart';
import '../../domain/entities/join_request.dart';
import '../../domain/repositories/members_repository.dart';
import '../datasources/members_remote_data_source.dart';

/// Implementación del repositorio de miembros
class MembersRepositoryImpl implements MembersRepository {
  final MembersRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MembersRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ClubMember>>> getClubMembers({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final members = await remoteDataSource.getClubMembers(
        clubId: clubId,
        sectionId: sectionId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(members);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ClubMember>> getMemberDetail(String userId,
      {RequestCancelToken? cancelToken}) async {
    try {
      final member = await remoteDataSource.getMemberDetail(userId,
          cancelToken: cancelToken.asDioCancelToken());
      return Right(member);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<JoinRequest>>> getJoinRequests({
    required int clubId,
    required int sectionId,
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final requests = await remoteDataSource.getJoinRequests(
        clubId: clubId,
        sectionId: sectionId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(requests);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, JoinRequest>> approveJoinRequest(
      String assignmentId) async {
    try {
      final request = await remoteDataSource.approveJoinRequest(assignmentId);
      return Right(request);
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, JoinRequest>> rejectJoinRequest(
      String assignmentId) async {
    try {
      final request = await remoteDataSource.rejectJoinRequest(assignmentId);
      return Right(request);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> assignClubRole({
    required int clubId,
    required int sectionId,
    required String userId,
    required String role,
  }) async {
    try {
      final result = await remoteDataSource.assignClubRole(
        clubId: clubId,
        sectionId: sectionId,
        userId: userId,
        role: role,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } on ServerException catch (e) {
      return Left(ServerFailure(
          message: e.message, code: e.code, errorCode: e.errorCode));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, bool>> removeClubRole(String assignmentId) async {
    try {
      final result = await remoteDataSource.removeClubRole(assignmentId);
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, AssignableRolesResult>> getAssignableRoles({
    required int clubId,
    required int sectionId,
    required String userId,
  }) async {
    try {
      final result = await remoteDataSource.getAssignableRoles(
        clubId: clubId,
        sectionId: sectionId,
        userId: userId,
      );
      return Right(result);
    } on DioException catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<AnnualContinuation>>> getAnnualContinuations(
      int sectionId) async {
    try {
      final models = await remoteDataSource.getAnnualContinuations(sectionId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) rethrow;
      return Left(UnexpectedFailure(message: e.toString()));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ContinuationBatchResult>> submitAnnualContinuations({
    required int sectionId,
    required List<String> userIds,
  }) async {
    try {
      final result = await remoteDataSource.submitAnnualContinuations(
        sectionId: sectionId,
        userIds: userIds,
      );
      return Right(result);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── Consentimiento de menores (Phase 2c) ──────────────────────────────────

  /// Conserva [Failure.errorCode] (`GUARDIANSHIP_*`, `MR_*`) para que la UI
  /// muestre el mensaje exacto; el cliente nunca lee `details`.
  Future<Either<Failure, T>> _guardKeepingCode<T>(
      Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        code: e.code,
        errorCode: e.errorCode,
      ));
    } on AuthException catch (e) {
      return Left(AuthFailure(
        message: e.message,
        code: e.code,
        errorCode: e.errorCode,
      ));
    } on ConnectionException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>> uploadConsentEvidence({
    required String assignmentId,
    required ConsentEvidenceLocalFile file,
  }) =>
      _guardKeepingCode(
        () => remoteDataSource.uploadConsentEvidence(
          assignmentId: assignmentId,
          file: file,
        ),
      );

  @override
  Future<Either<Failure, ConsentEvidenceAccess>> getConsentEvidence(
          String assignmentId) =>
      _guardKeepingCode(
        () => remoteDataSource.getConsentEvidence(assignmentId),
      );

  @override
  Future<Either<Failure, ConsentVerificationResult>> verifyConsent({
    required String assignmentId,
    required bool approve,
  }) =>
      _guardKeepingCode(
        () => remoteDataSource.verifyConsent(
          assignmentId: assignmentId,
          approve: approve,
        ),
      );

  // ── Director registra a un menor (Phase 3c) ───────────────────────────────

  @override
  Future<Either<Failure, CreatedMinor>> createMinor(CreateMinorInput input) =>
      _guardKeepingCode(() => remoteDataSource.createMinor(input));

  @override
  Future<Either<Failure, IssuedClaimCode>> issueClaimCode({
    required int clubSectionId,
    required String dependentUserId,
  }) =>
      _guardKeepingCode(
        () => remoteDataSource.issueClaimCode(
          clubSectionId: clubSectionId,
          dependentUserId: dependentUserId,
        ),
      );
}
