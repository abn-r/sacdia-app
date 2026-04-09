import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/progressive_class.dart';
import '../repositories/classes_repository.dart';

/// Caso de uso para obtener el detalle de una clase
class GetClassDetail implements UseCase<ProgressiveClass, GetClassDetailParams> {
  final ClassesRepository repository;

  GetClassDetail(this.repository);

  @override
  Future<Either<Failure, ProgressiveClass>> call(GetClassDetailParams params, {CancelToken? cancelToken}) async {
    return await repository.getClassById(params.classId, cancelToken: cancelToken);
  }
}

/// Parámetros para obtener el detalle de una clase
class GetClassDetailParams {
  final int classId;

  const GetClassDetailParams({required this.classId});
}
