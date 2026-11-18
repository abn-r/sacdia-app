import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/usecases/cancellation_token.dart';
import 'package:sacdia_app/features/resources/domain/entities/paginated_resources.dart';
import 'package:sacdia_app/features/resources/domain/entities/resource.dart';
import 'package:sacdia_app/features/resources/domain/entities/resource_category.dart';
import 'package:sacdia_app/features/resources/domain/repositories/resources_repository.dart';

/// One query the fake repository received.
class ResourcesCall {
  const ResourcesCall({
    required this.page,
    required this.limit,
    this.type,
    this.categoryId,
    this.search,
  });

  final int page;
  final int limit;
  final String? type;
  final int? categoryId;
  final String? search;
}

/// In-memory [ResourcesRepository] that filters like the server does.
class FakeResourcesRepository implements ResourcesRepository {
  FakeResourcesRepository({
    this.resources = const [],
    this.categories = const [],
    this.categoriesForbidden = false,
    this.gate,
  });

  final List<Resource> resources;
  final List<ResourceCategory> categories;

  /// Simulates `/resource-categories` answering 403 (no `resource_categories:read`).
  final bool categoriesForbidden;

  /// When set, list calls wait for it (keeps the screen in its loading state).
  final Completer<void>? gate;

  final List<ResourcesCall> calls = [];

  /// Calls made by the grid (page size 20), not by facet lookups (100).
  List<ResourcesCall> get gridCalls =>
      calls.where((call) => call.limit == 20).toList();

  @override
  Future<Either<Failure, PaginatedResources>> getVisibleResources({
    int page = 1,
    int limit = 20,
    String? resourceType,
    int? categoryId,
    String? search,
    RequestCancelToken? cancelToken,
  }) async {
    calls.add(ResourcesCall(
      page: page,
      limit: limit,
      type: resourceType,
      categoryId: categoryId,
      search: search,
    ));
    if (gate != null && limit == 20) await gate!.future;

    final query = search?.toLowerCase();
    final matches = resources.where((r) {
      if (resourceType != null && r.resourceType != resourceType) return false;
      if (categoryId != null && r.resourceCategoryId != categoryId) {
        return false;
      }
      if (query != null && !r.title.toLowerCase().contains(query)) {
        return false;
      }
      return true;
    }).toList();
    final start = (page - 1) * limit;
    final pageItems = matches.skip(start).take(limit).toList();
    return Right(PaginatedResources(
      data: pageItems,
      total: matches.length,
      page: page,
      limit: limit,
    ));
  }

  @override
  Future<Either<Failure, Resource>> getResource(String id,
          {RequestCancelToken? cancelToken}) async =>
      Right(resources.firstWhere((r) => r.resourceId == id));

  @override
  Future<Either<Failure, String>> getSignedUrl(String id,
          {RequestCancelToken? cancelToken}) async =>
      const Right('https://files.example/signed');

  @override
  Future<Either<Failure, List<ResourceCategory>>> getCategories(
          {RequestCancelToken? cancelToken}) async =>
      categoriesForbidden
          ? const Left(ServerFailure(message: 'Forbidden'))
          : Right(categories);
}

Resource testResource({
  required String id,
  required String title,
  String type = 'document',
  int? categoryId,
  String? categoryName,
  String? clubTypeName,
  String scopeLevel = 'local_field',
  String? fileName,
  String? mime,
  String? externalUrl,
  String? signedUrl,
  String? content,
  int? fileSize = 2048,
}) {
  return Resource(
    resourceId: id,
    title: title,
    resourceType: type,
    resourceCategoryId: categoryId,
    categoryName: categoryName,
    clubTypeName: clubTypeName,
    scopeLevel: scopeLevel,
    fileName: fileName,
    fileMimeType: mime,
    fileSize: fileSize,
    externalUrl: externalUrl,
    signedUrl: signedUrl,
    content: content,
    createdAt: DateTime(2026, 11, 12),
  );
}
