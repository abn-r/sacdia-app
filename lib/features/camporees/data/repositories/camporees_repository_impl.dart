import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/models/paginated_result.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../domain/entities/camporee.dart';
import '../../domain/entities/camporee_event.dart';
import '../../domain/entities/camporee_judge_assignment.dart';
import '../../domain/entities/camporee_leaderboard.dart';
import '../../domain/entities/camporee_member.dart';
import '../../domain/entities/camporee_payment.dart';
import '../../domain/entities/camporee_rubric.dart';
import '../../domain/entities/camporee_section_registration.dart';
import '../../domain/entities/camporee_score_submission.dart';
import '../../domain/repositories/camporees_repository.dart';
import '../datasources/camporees_remote_data_source.dart';

/// Implementación del repositorio de camporees.
class CamporeesRepositoryImpl implements CamporeesRepository {
  final CamporeesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CamporeesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Left<Failure, T> _appFailure<T>(AppException exception) {
    final Failure failure;
    if (exception is ServerException) {
      failure = ServerFailure(
        message: exception.message,
        code: exception.code,
        stackTrace: exception.stackTrace,
      );
    } else if (exception is AuthException) {
      failure = AuthFailure(
        message: exception.message,
        code: exception.code,
        stackTrace: exception.stackTrace,
      );
    } else if (exception is ConnectionException) {
      failure = NetworkFailure(
        message: exception.message,
        stackTrace: exception.stackTrace,
      );
    } else if (exception is ValidationException) {
      failure = ValidationFailure(
        message: exception.message,
        fieldsErrors: exception.fieldsErrors,
        stackTrace: exception.stackTrace,
      );
    } else if (exception is NotFoundException) {
      failure = NotFoundFailure(
        message: exception.message,
        code: exception.code,
        stackTrace: exception.stackTrace,
      );
    } else if (exception is CacheException) {
      failure = CacheFailure(
        message: exception.message,
        stackTrace: exception.stackTrace,
      );
    } else if (exception is OAuthFlowInitiatedException) {
      failure = OAuthFlowInitiatedFailure(provider: exception.provider);
    } else {
      failure = UnexpectedFailure(
        message: exception.message,
        stackTrace: exception.stackTrace,
      );
    }
    return Left(failure);
  }

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── Métodos ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Camporee>>> getCamporees(
      {bool? active, RequestCancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getCamporees(
          active: active, cancelToken: cancelToken.asDioCancelToken());
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, Camporee>> getCamporeeDetail(int camporeeId,
      {RequestCancelToken? cancelToken}) async {
    try {
      final model = await remoteDataSource.getCamporeeDetail(camporeeId,
          cancelToken: cancelToken.asDioCancelToken());
      return Right(model.toEntity());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CamporeeSectionRegistration>>
      getActiveSectionRegistration(int camporeeId) async {
    try {
      final model =
          await remoteDataSource.getActiveSectionRegistration(camporeeId);
      return Right(model.toEntity());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CamporeeSectionRegistration>> registerActiveSection(
    int camporeeId,
  ) async {
    try {
      final model = await remoteDataSource.registerActiveSection(camporeeId);
      return Right(model.toEntity());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeeEvent>>> getCamporeeEvents(
    int camporeeId, {
    String camporeeType = 'local',
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getCamporeeEvents(
        camporeeId,
        camporeeType: camporeeType,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CamporeeMember>> registerMember(
    int camporeeId, {
    required String userId,
    String? camporeeType,
    String? clubName,
    required int insuranceId,
  }) async {
    try {
      final model = await remoteDataSource.registerMember(
        camporeeId,
        userId: userId,
        camporeeType: camporeeType,
        clubName: clubName,
        insuranceId: insuranceId,
      );
      return Right(model.toEntity());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, PaginatedResult<CamporeeMember>>> getCamporeeMembers(
    int camporeeId, {
    int page = 1,
    int limit = 50,
    String? status,
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final paginated = await remoteDataSource.getCamporeeMembers(
        camporeeId,
        page: page,
        limit: limit,
        status: status,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      final entities = PaginatedResult<CamporeeMember>(
        data: paginated.data.map((m) => m.toEntity()).toList(),
        meta: paginated.meta,
      );
      return Right(entities);
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> removeMember(
      int camporeeId, String userId) async {
    try {
      await remoteDataSource.removeMember(camporeeId, userId);
      return const Right(null);
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Payments ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, CamporeeEnrolledClub>> enrollClub(
    int camporeeId,
  ) async {
    try {
      final model = await remoteDataSource.enrollClub(camporeeId);
      return Right(model.toEntity());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeeEnrolledClub>>> getEnrolledClubs(
      int camporeeId,
      {RequestCancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getEnrolledClubs(camporeeId,
          cancelToken: cancelToken.asDioCancelToken());
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CamporeePayment>> createPayment(
    int camporeeId,
    String memberId, {
    required double amount,
    required String paymentType,
    String? reference,
    DateTime? paymentDate,
    String? notes,
  }) async {
    try {
      final model = await remoteDataSource.createPayment(
        camporeeId,
        memberId,
        amount: amount,
        paymentType: paymentType,
        reference: reference,
        paymentDate: paymentDate,
        notes: notes,
      );
      return Right(model.toEntity());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeePayment>>> getMemberPayments(
    int camporeeId,
    String memberId, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getMemberPayments(
          camporeeId, memberId,
          cancelToken: cancelToken.asDioCancelToken());
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeePayment>>> getCamporeePayments(
      int camporeeId,
      {RequestCancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getCamporeePayments(camporeeId,
          cancelToken: cancelToken.asDioCancelToken());
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeeJudgeAssignment>>> getMyJudgeAssignments(
      {RequestCancelToken? cancelToken}) async {
    try {
      final models = await remoteDataSource.getMyJudgeAssignments(
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CamporeeLeaderboard>> getCamporeeLeaderboard(
    int camporeeId, {
    String camporeeType = 'local',
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getCamporeeLeaderboard(
        camporeeId,
        camporeeType: camporeeType,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(model.toEntity());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeeRubric>>> getCamporeeEventRubrics(
    int eventId, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getCamporeeEventRubrics(
        eventId,
        cancelToken: cancelToken.asDioCancelToken(),
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> submitCamporeeEventScore(
    int eventId,
    int clubSectionId, {
    required CamporeeScoreSubmission submission,
  }) async {
    try {
      await remoteDataSource.submitCamporeeEventScore(
        eventId,
        clubSectionId,
        submission: submission,
      );
      return const Right(null);
    } on AppException catch (e) {
      return _appFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
