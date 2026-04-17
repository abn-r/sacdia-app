import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/honor_category.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para obtener las categorías de especialidades
class GetHonorCategories implements UseCase<List<HonorCategory>, NoParams> {
  final HonorsRepository repository;

  GetHonorCategories(this.repository);

  @override
  Future<Either<Failure, List<HonorCategory>>> call(NoParams params, {CancelToken? cancelToken}) async {
    return await repository.getHonorCategories(cancelToken: cancelToken);
  }
}
