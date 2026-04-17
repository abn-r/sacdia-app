import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

/// Caso de uso para obtener el resumen del dashboard del usuario autenticado
class GetDashboardSummary implements UseCase<DashboardSummary, NoParams> {
  final DashboardRepository repository;

  GetDashboardSummary(this.repository);

  @override
  Future<Either<Failure, DashboardSummary>> call(NoParams params, {CancelToken? cancelToken}) async {
    return await repository.getDashboardSummary(cancelToken: cancelToken);
  }
}
