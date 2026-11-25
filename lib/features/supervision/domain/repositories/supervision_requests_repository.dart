import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_request.dart';

abstract class SupervisionRequestsRepository {
  Future<Either<Failure, List<SupervisionRequest>>> getRequests({
    required SupervisionRequestKind kind,
    required SupervisionRequestStatus status,
    RequestCancelToken? cancelToken,
  });

  Future<Either<Failure, SupervisionRequest>> review({
    required SupervisionRequestKind kind,
    required String requestId,
    required bool approve,
    String? comment,
  });
}
