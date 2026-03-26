import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/paginated_resources.dart';
import '../../domain/entities/resource.dart';
import '../../domain/entities/resource_category.dart';
import '../../domain/repositories/resources_repository.dart';
import '../datasources/resources_remote_datasource.dart';

/// Implementación del repositorio de recursos
class ResourcesRepositoryImpl implements ResourcesRepository {
  final ResourcesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  ResourcesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, PaginatedResources>> getVisibleResources({
    int page = 1,
    int limit = 20,
    String? resourceType,
    int? categoryId,
    String? search,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final model = await remoteDataSource.getVisibleResources(
        page: page,
        limit: limit,
        resourceType: resourceType,
        categoryId: categoryId,
        search: search,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Resource>> getResource(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final model = await remoteDataSource.getResource(id);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> getSignedUrl(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final url = await remoteDataSource.getSignedUrl(id);
      return Right(url);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ResourceCategory>>> getCategories() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }

    try {
      final categoryModels = await remoteDataSource.getCategories();
      final categories =
          categoryModels.map((model) => model.toEntity()).toList();
      return Right(categories);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
