import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/honor.dart';
import '../repositories/honors_repository.dart';

/// Caso de uso para obtener especialidades filtradas
class GetHonors implements UseCase<List<Honor>, GetHonorsParams> {
  final HonorsRepository repository;

  GetHonors(this.repository);

  @override
  Future<Either<Failure, List<Honor>>> call(GetHonorsParams params) async {
    return await repository.getHonors(
      categoryId: params.categoryId,
      clubTypeId: params.clubTypeId,
      skillLevel: params.skillLevel,
    );
  }
}

/// Parámetros para obtener especialidades
class GetHonorsParams {
  final int? categoryId;
  final int? clubTypeId;
  final int? skillLevel;

  const GetHonorsParams({
    this.categoryId,
    this.clubTypeId,
    this.skillLevel,
  });
}
