import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../entities/dashboard_summary.dart';

/// Interfaz del repositorio de dashboard
abstract class DashboardRepository {
  /// Obtiene el resumen del dashboard para un usuario
  Future<Either<Failure, DashboardSummary>> getDashboardData(
    String userId, {
    Map<String, dynamic>? userMetadata,
  });
}
