import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../providers/dio_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/resources_remote_datasource.dart';
import '../../data/repositories/resources_repository_impl.dart';
import '../../domain/entities/paginated_resources.dart';
import '../../domain/entities/resource.dart';
import '../../domain/entities/resource_category.dart';
import '../../domain/repositories/resources_repository.dart';
import '../../domain/usecases/get_resource_categories.dart';
import '../../domain/usecases/get_resource_signed_url.dart';
import '../../domain/usecases/get_visible_resources.dart';

// ── Infrastructure providers ────────────────────────────────────────────────

/// Provider para la fuente de datos remota de recursos
final resourcesRemoteDataSourceProvider =
    Provider<ResourcesRemoteDataSource>((ref) {
  final dio = ref.read(dioProvider);
  final baseUrl = ref.read(apiBaseUrlProvider);
  return ResourcesRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
});

/// Provider para el repositorio de recursos
final resourcesRepositoryProvider = Provider<ResourcesRepository>((ref) {
  final remoteDataSource = ref.read(resourcesRemoteDataSourceProvider);
  final networkInfo = ref.read(networkInfoProvider);
  return ResourcesRepositoryImpl(
    remoteDataSource: remoteDataSource,
    networkInfo: networkInfo,
  );
});

// ── Use case providers ───────────────────────────────────────────────────────

/// Provider para el caso de uso de obtener recursos visibles
final getVisibleResourcesProvider = Provider<GetVisibleResources>((ref) {
  return GetVisibleResources(ref.read(resourcesRepositoryProvider));
});

/// Provider para el caso de uso de obtener URL firmada
final getResourceSignedUrlProvider = Provider<GetResourceSignedUrl>((ref) {
  return GetResourceSignedUrl(ref.read(resourcesRepositoryProvider));
});

/// Provider para el caso de uso de obtener categorías
final getResourceCategoriesProvider = Provider<GetResourceCategories>((ref) {
  return GetResourceCategories(ref.read(resourcesRepositoryProvider));
});

// ── Filter state providers ───────────────────────────────────────────────────

/// Tipo de recurso seleccionado para filtrar. null = "Todos"
final selectedResourceTypeProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Categoría seleccionada para filtrar. null = todas
final selectedResourceCategoryProvider =
    StateProvider.autoDispose<int?>((ref) => null);

/// Texto de búsqueda
final resourceSearchProvider = StateProvider.autoDispose<String>((ref) => '');

// ── Data providers ───────────────────────────────────────────────────────────

/// Provider para las categorías de recursos
final resourceCategoriesProvider =
    FutureProvider.autoDispose<List<ResourceCategory>>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final getCategories = ref.read(getResourceCategoriesProvider);
  final result =
      await getCategories(const NoParams(), cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});

/// Provider para la primera página de recursos (con filtros activos)
final resourcesProvider =
    FutureProvider.autoDispose<PaginatedResources>((ref) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final resourceType = ref.watch(selectedResourceTypeProvider);
  final categoryId = ref.watch(selectedResourceCategoryProvider);
  final search = ref.watch(resourceSearchProvider);

  final getResources = ref.read(getVisibleResourcesProvider);
  final result = await getResources(
    GetVisibleResourcesParams(
      page: 1,
      limit: 20,
      resourceType: resourceType,
      categoryId: categoryId,
      search: search.isEmpty ? null : search,
    ),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (paginated) => paginated,
  );
});

// ── Paginated notifier ───────────────────────────────────────────────────────

/// Estado para la lista paginada de recursos
class ResourcesListState {
  final List<Resource> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final String? errorMessage;

  const ResourcesListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 0,
    this.errorMessage,
  });

  ResourcesListState copyWith({
    List<Resource>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    String? errorMessage,
  }) {
    return ResourcesListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier que gestiona la lista paginada de recursos con carga incremental
class ResourcesListNotifier extends Notifier<ResourcesListState> {
  static const int _pageSize = 20;
  CancelToken? _cancelToken;

  @override
  ResourcesListState build() {
    // Cuando cambian los filtros, reiniciar la lista automáticamente
    ref.watch(selectedResourceTypeProvider);
    ref.watch(selectedResourceCategoryProvider);
    ref.watch(resourceSearchProvider);

    ref.onDispose(() => _cancelToken?.cancel());

    // Diferir la primera carga para después del build
    Future.microtask(() => loadFirstPage());

    return const ResourcesListState(isLoading: true);
  }

  Future<void> loadFirstPage() async {
    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    state = state.copyWith(isLoading: true, errorMessage: null);

    final resourceType = ref.read(selectedResourceTypeProvider);
    final categoryId = ref.read(selectedResourceCategoryProvider);
    final search = ref.read(resourceSearchProvider);

    final getResources = ref.read(getVisibleResourcesProvider);
    final result = await getResources(
      GetVisibleResourcesParams(
        page: 1,
        limit: _pageSize,
        resourceType: resourceType,
        categoryId: categoryId,
        search: search.isEmpty ? null : search,
      ),
      cancelToken: _cancelToken,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        errorMessage: failure.message,
      ),
      (paginated) => state = state.copyWith(
        items: paginated.data,
        isLoading: false,
        hasMore: paginated.hasMore,
        currentPage: 1,
      ),
    );
  }

  Future<void> loadNextPage() async {
    if (state.isLoadingMore || !state.hasMore) return;

    _cancelToken?.cancel();
    _cancelToken = CancelToken();
    state = state.copyWith(isLoadingMore: true);

    final nextPage = state.currentPage + 1;
    final resourceType = ref.read(selectedResourceTypeProvider);
    final categoryId = ref.read(selectedResourceCategoryProvider);
    final search = ref.read(resourceSearchProvider);

    final getResources = ref.read(getVisibleResourcesProvider);
    final result = await getResources(
      GetVisibleResourcesParams(
        page: nextPage,
        limit: _pageSize,
        resourceType: resourceType,
        categoryId: categoryId,
        search: search.isEmpty ? null : search,
      ),
      cancelToken: _cancelToken,
    );

    result.fold(
      (failure) => state = state.copyWith(
        isLoadingMore: false,
        errorMessage: failure.message,
      ),
      (paginated) => state = state.copyWith(
        items: [...state.items, ...paginated.data],
        isLoadingMore: false,
        hasMore: paginated.hasMore,
        currentPage: nextPage,
      ),
    );
  }
}

/// Provider del notifier de lista paginada de recursos
final resourcesListNotifierProvider =
    NotifierProvider.autoDispose<ResourcesListNotifier, ResourcesListState>(
  ResourcesListNotifier.new,
);

// ── Signed URL notifier ──────────────────────────────────────────────────────

/// Notifier para gestionar la obtención de URLs firmadas de descarga
class SignedUrlNotifier extends Notifier<AsyncValue<String?>> {
  @override
  AsyncValue<String?> build() => const AsyncValue.data(null);

  Future<String?> fetchSignedUrl(String resourceId) async {
    state = const AsyncValue.loading();

    final getSignedUrl = ref.read(getResourceSignedUrlProvider);
    final result = await getSignedUrl(resourceId);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure.message, StackTrace.current);
        return null;
      },
      (url) {
        state = AsyncValue.data(url);
        return url;
      },
    );
  }

  void reset() => state = const AsyncValue.data(null);
}

/// Provider del notifier de URLs firmadas
final signedUrlNotifierProvider =
    NotifierProvider.autoDispose<SignedUrlNotifier, AsyncValue<String?>>(
  SignedUrlNotifier.new,
);

/// Signed URL per resource for grid previews. Family so tiles do not clobber
/// each other (unlike [signedUrlNotifierProvider]).
final resourcePreviewSignedUrlProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, resourceId) async {
  final getSignedUrl = ref.read(getResourceSignedUrlProvider);
  final result = await getSignedUrl(resourceId);
  return result.fold((_) => null, (url) => url);
});

// ── Facets (category counts, matches in other types) ────────────────────────

/// Query for [resourceFacetProvider]: the filters a facet is computed under.
class ResourceFacetQuery extends Equatable {
  final String? type;
  final String search;
  final int? categoryId;

  const ResourceFacetQuery({this.type, this.search = '', this.categoryId});

  @override
  List<Object?> get props => [type, search, categoryId];
}

/// Aggregate of one unpaginated look at the library.
class ResourceFacet extends Equatable {
  /// Total matches reported by the server for the query.
  final int total;

  /// Matches per `resource_category_id`. Only trustworthy when [isComplete].
  final Map<int, int> categoryCounts;

  /// Category names read off the loaded resources, by `resource_category_id`.
  /// Lets the category filter work without `/resource-categories`.
  final Map<int, String> categoryNames;

  /// True when every match came back in the single request (no more pages),
  /// so [categoryCounts] covers all of them.
  final bool isComplete;

  const ResourceFacet({
    required this.total,
    required this.categoryCounts,
    required this.isComplete,
    this.categoryNames = const {},
  });

  @override
  List<Object?> get props => [total, categoryCounts, isComplete, categoryNames];
}

/// Backend cap for `limit` (see `ResourceQueryDto`).
const int _facetPageSize = 100;

/// Counts the library under [ResourceFacetQuery] without paginating the grid.
///
/// The API has no counts endpoint, so this reads one page of up to 100 items
/// and tallies categories client side. When there are more than 100 matches
/// [ResourceFacet.isComplete] is false and callers must not show counts.
final resourceFacetProvider = FutureProvider.autoDispose
    .family<ResourceFacet, ResourceFacetQuery>((ref, query) async {
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());

  final getResources = ref.read(getVisibleResourcesProvider);
  final result = await getResources(
    GetVisibleResourcesParams(
      page: 1,
      limit: _facetPageSize,
      resourceType: query.type,
      categoryId: query.categoryId,
      search: query.search.isEmpty ? null : query.search,
    ),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (paginated) {
      final counts = <int, int>{};
      final names = <int, String>{};
      for (final resource in paginated.data) {
        final id = resource.resourceCategoryId;
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
        final name = resource.categoryName?.trim();
        if (name != null && name.isNotEmpty) names.putIfAbsent(id, () => name);
      }
      return ResourceFacet(
        total: paginated.total,
        categoryCounts: counts,
        categoryNames: names,
        isComplete: !paginated.hasMore,
      );
    },
  );
});

/// Categories for the filter bar, derived from the loaded resources so it
/// works for roles without `resource_categories:read` (the endpoint answers
/// 403). `/resource-categories` is optional enrichment: when it succeeds its
/// categories come first, in server order; a failure is ignored.
final resourceCategoryOptionsProvider =
    Provider.autoDispose<List<ResourceCategory>>((ref) {
  final server = ref.watch(resourceCategoriesProvider).value ?? const [];
  final library =
      ref.watch(resourceFacetProvider(const ResourceFacetQuery())).value;

  final byId = <int, ResourceCategory>{
    for (final category in server) category.resourceCategoryId: category,
  };
  if (library != null) {
    final derived = library.categoryNames.entries
        .where((entry) => !byId.containsKey(entry.key))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    for (final entry in derived) {
      byId[entry.key] =
          ResourceCategory(resourceCategoryId: entry.key, name: entry.value);
    }
  }
  return byId.values.toList();
});

// ── Sharing ──────────────────────────────────────────────────────────────────

/// Opens the platform share sheet. Overridable in tests.
typedef ResourceSharer = Future<void> Function({
  required String text,
  required String subject,
});

final resourceSharerProvider = Provider<ResourceSharer>((ref) {
  return ({required String text, required String subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  };
});
