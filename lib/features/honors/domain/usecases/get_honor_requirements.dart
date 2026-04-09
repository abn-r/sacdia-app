import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/honor_requirement.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para obtener los requisitos del catálogo de una especialidad
class GetHonorRequirements
    implements UseCase<List<HonorRequirement>, GetHonorRequirementsParams> {
  final HonorsRepository repository;

  GetHonorRequirements(this.repository);

  @override
  Future<Either<Failure, List<HonorRequirement>>> call(
      GetHonorRequirementsParams params, {CancelToken? cancelToken}) async {
    return await repository.getHonorRequirements(params.honorId, cancelToken: cancelToken);
  }
}

/// Parámetros para obtener los requisitos de una especialidad
class GetHonorRequirementsParams {
  final int honorId;

  const GetHonorRequirementsParams({required this.honorId});
}
