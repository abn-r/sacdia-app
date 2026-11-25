import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/supervision_operations.dart';

abstract class SupervisionOperationsRepository {
  /// GET /admin/analytics/operations-dashboard
  Future<Either<Failure, SupervisionOperationsDashboard>> getDashboard(
    SupervisionOperationsQuery query, {
    RequestCancelToken? cancelToken,
  });
}
