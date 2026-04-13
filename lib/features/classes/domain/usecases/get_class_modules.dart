import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/class_module.dart';
import '../repositories/classes_repository.dart';

/// Caso de uso para obtener los módulos de una clase
class GetClassModules implements UseCase<List<ClassModule>, GetClassModulesParams> {
  final ClassesRepository repository;

  GetClassModules(this.repository);

  @override
  Future<Either<Failure, List<ClassModule>>> call(GetClassModulesParams params, {CancelToken? cancelToken}) async {
    return await repository.getClassModules(params.classId, cancelToken: cancelToken);
  }
}

/// Parámetros para obtener los módulos de una clase
class GetClassModulesParams {
  final int classId;

  const GetClassModulesParams({required this.classId});
}
