import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/paginated_resources.dart';
import '../repositories/resources_repository.dart';

/// Caso de uso para obtener los recursos visibles al usuario
class GetVisibleResources
    implements UseCase<PaginatedResources, GetVisibleResourcesParams> {
  final ResourcesRepository repository;

  GetVisibleResources(this.repository);

  @override
  Future<Either<Failure, PaginatedResources>> call(
    GetVisibleResourcesParams params, {CancelToken? cancelToken}
  ) async {
    return await repository.getVisibleResources(
      page: params.page,
      limit: params.limit,
      resourceType: params.resourceType,
      categoryId: params.categoryId,
      search: params.search,
      cancelToken: cancelToken,
    );
  }
}

/// Parámetros para obtener recursos visibles
class GetVisibleResourcesParams {
  final int page;
  final int limit;
  final String? resourceType;
  final int? categoryId;
  final String? search;

  const GetVisibleResourcesParams({
    this.page = 1,
    this.limit = 20,
    this.resourceType,
    this.categoryId,
    this.search,
  });
}
