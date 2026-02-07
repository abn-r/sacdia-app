import 'package:dartz/dartz.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// Parámetros para obtener datos del dashboard
class GetDashboardDataParams {
  final String userId;

  const GetDashboardDataParams({required this.userId});
}

/// Caso de uso para obtener los datos del dashboard
class GetDashboardData implements UseCase<DashboardSummary, GetDashboardDataParams> {
  final DashboardRepository repository;

  GetDashboardData(this.repository);

  @override
  Future<Either<Failure, DashboardSummary>> call(GetDashboardDataParams params) async {
    return await repository.getDashboardData(params.userId);
  }
}
