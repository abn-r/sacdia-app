import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/resource.dart';
import '../repositories/resources_repository.dart';

/// Caso de uso para obtener el detalle de un recurso
class GetResource implements UseCase<Resource, String> {
  final ResourcesRepository repository;

  GetResource(this.repository);

  @override
  Future<Either<Failure, Resource>> call(String id, {CancelToken? cancelToken}) async {
    return await repository.getResource(id, cancelToken: cancelToken);
  }
}
