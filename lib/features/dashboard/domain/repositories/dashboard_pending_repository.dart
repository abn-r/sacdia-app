import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/dashboard_pending.dart';

/// Contrato de los pendientes de gestión del inicio.
abstract class DashboardPendingRepository {
  Future<Either<Failure, DashboardPending>> getPending({
    RequestCancelToken? cancelToken,
  });
}
