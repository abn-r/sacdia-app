import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/resources_repository.dart';

/// Caso de uso para obtener la URL firmada de descarga de un recurso
class GetResourceSignedUrl implements UseCase<String, String> {
  final ResourcesRepository repository;

  GetResourceSignedUrl(this.repository);

  @override
  Future<Either<Failure, String>> call(String id, {CancelToken? cancelToken}) async {
    return await repository.getSignedUrl(id, cancelToken: cancelToken);
  }
}
