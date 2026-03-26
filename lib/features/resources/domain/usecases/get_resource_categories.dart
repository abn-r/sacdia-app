import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/resource_category.dart';
import '../repositories/resources_repository.dart';

/// Caso de uso para obtener las categorías de recursos
class GetResourceCategories
    implements UseCase<List<ResourceCategory>, NoParams> {
  final ResourcesRepository repository;

  GetResourceCategories(this.repository);

  @override
  Future<Either<Failure, List<ResourceCategory>>> call(NoParams params) async {
    return await repository.getCategories();
  }
}
