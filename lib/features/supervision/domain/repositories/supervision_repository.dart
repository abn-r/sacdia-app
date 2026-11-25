import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_pending_counts.dart';

abstract class SupervisionRepository {
  /// GET /supervision/pending-counts
  Future<Either<Failure, SupervisionPendingCounts>> getPendingCounts({
    RequestCancelToken? cancelToken,
  });
}
