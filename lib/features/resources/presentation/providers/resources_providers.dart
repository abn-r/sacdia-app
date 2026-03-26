import 'package:flutter_riverpod/flutter_riverpod.dart';
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
final resourceSearchProvider =
    StateProvider.autoDispose<String>((ref) => '');

// ── Data providers ───────────────────────────────────────────────────────────

/// Provider para las categorías de recursos
final resourceCategoriesProvider =
    FutureProvider.autoDispose<List<ResourceCategory>>((ref) async {
  final getCategories = ref.read(getResourceCategoriesProvider);
  final result = await getCategories(const NoParams());
  return result.fold(
    (failure) => throw Exception(failure.message),
    (categories) => categories,
  );
});

/// Provider para la primera página de recursos (con filtros activos)
final resourcesProvider =
    FutureProvider.autoDispose<PaginatedResources>((ref) async {
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
class ResourcesListNotifier extends AutoDisposeNotifier<ResourcesListState> {
  static const int _pageSize = 20;

  @override
  ResourcesListState build() {
    // Cuando cambian los filtros, reiniciar la lista automáticamente
    ref.watch(selectedResourceTypeProvider);
    ref.watch(selectedResourceCategoryProvider);
    ref.watch(resourceSearchProvider);

    // Diferir la primera carga para después del build
    Future.microtask(() => loadFirstPage());

    return const ResourcesListState(isLoading: true);
  }

  Future<void> loadFirstPage() async {
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
    AutoDisposeNotifierProvider<ResourcesListNotifier, ResourcesListState>(
  ResourcesListNotifier.new,
);

// ── Signed URL notifier ──────────────────────────────────────────────────────

/// Notifier para gestionar la obtención de URLs firmadas de descarga
class SignedUrlNotifier extends AutoDisposeNotifier<AsyncValue<String?>> {
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
    AutoDisposeNotifierProvider<SignedUrlNotifier, AsyncValue<String?>>(
  SignedUrlNotifier.new,
);
