import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/paginated_resources.dart';
import '../entities/resource.dart';
import '../entities/resource_category.dart';

/// Repositorio de recursos (interfaz del dominio)
abstract class ResourcesRepository {
  /// Obtiene los recursos visibles para el usuario autenticado (paginados)
  Future<Either<Failure, PaginatedResources>> getVisibleResources({
    int page = 1,
    int limit = 20,
    String? resourceType,
    int? categoryId,
    String? search,
  });

  /// Obtiene el detalle de un recurso por ID
  Future<Either<Failure, Resource>> getResource(String id);

  /// Obtiene la URL firmada de descarga de un recurso
  Future<Either<Failure, String>> getSignedUrl(String id);

  /// Obtiene todas las categorías de recursos
  Future<Either<Failure, List<ResourceCategory>>> getCategories();
}
