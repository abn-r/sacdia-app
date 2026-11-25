import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_enrollment.dart';

abstract class SupervisionEnrollmentsRepository {
  /// GET /club-enrollments/validation/queue
  Future<Either<Failure, SupervisionEnrollmentPage>> getQueue({
    SupervisionEnrollmentStatus status =
        SupervisionEnrollmentStatus.pendingValidation,
    String? search,
    int page = 1,
    int limit = 20,
    RequestCancelToken? cancelToken,
  });

  /// POST /club-enrollments/:id/approve
  Future<Either<Failure, SupervisionEnrollment>> approve(
    String enrollmentId, {
    RequestCancelToken? cancelToken,
  });

  /// POST /club-enrollments/:id/reject
  Future<Either<Failure, SupervisionEnrollment>> reject(
    String enrollmentId,
    String reason, {
    RequestCancelToken? cancelToken,
  });
}
