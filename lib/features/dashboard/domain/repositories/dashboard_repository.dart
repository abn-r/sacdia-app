import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dashboard_summary.dart';

/// Interfaz del repositorio de dashboard
abstract class DashboardRepository {
  /// Obtiene el resumen del dashboard del usuario autenticado
  Future<Either<Failure, DashboardSummary>> getDashboardSummary({CancelToken? cancelToken});
}
