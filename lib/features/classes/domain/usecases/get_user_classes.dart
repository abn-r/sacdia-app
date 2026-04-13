import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/progressive_class.dart';
import '../repositories/classes_repository.dart';

/// Caso de uso para obtener las clases de un usuario
class GetUserClasses implements UseCase<List<ProgressiveClass>, GetUserClassesParams> {
  final ClassesRepository repository;

  GetUserClasses(this.repository);

  @override
  Future<Either<Failure, List<ProgressiveClass>>> call(GetUserClassesParams params, {CancelToken? cancelToken}) async {
    return await repository.getUserClasses(params.userId, cancelToken: cancelToken);
  }
}

/// Parámetros para obtener las clases de un usuario
class GetUserClassesParams {
  final String userId;

  const GetUserClassesParams({required this.userId});
}
