import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../entities/dashboard_summary.dart';

/// Interfaz del repositorio de dashboard
abstract class DashboardRepository {
  /// Obtiene el resumen del dashboard del usuario autenticado
  Future<Either<Failure, DashboardSummary>> getDashboardSummary(
      {RequestCancelToken? cancelToken});
}
