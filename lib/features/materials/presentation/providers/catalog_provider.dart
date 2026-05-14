import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/material_item.dart';
import '../../domain/usecases/browse_catalog.dart';
import 'materials_providers.dart';

/// Parámetros de consulta del catálogo.
class CatalogQuery extends Equatable {
  final String? cat;
  final int? programaId;
  final String? q;

  const CatalogQuery({
    this.cat,
    this.programaId,
    this.q,
  });

  @override
  List<Object?> get props => [cat, programaId, q];
}

/// Estado del catálogo paginado.
class CatalogState extends Equatable {
  final List<MaterialItem> items;
  final int total;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;
  final String? errorMessage;

  const CatalogState({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  CatalogState copyWith({
    List<MaterialItem>? items,
    int? total,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return CatalogState(
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [items, total, page, hasMore, isLoadingMore, errorMessage];
}

/// Notifier del catálogo con soporte de paginación incremental.
///
/// La primera carga se dispara automáticamente en [build].
/// Llama [loadMore] para añadir la siguiente página.
class CatalogNotifier
    extends AutoDisposeFamilyAsyncNotifier<CatalogState, CatalogQuery> {
  static const _pageSize = 20;

  @override
  Future<CatalogState> build(CatalogQuery query) async {
    return _fetchPage(query: query, page: 1, existing: const []);
  }

  /// Carga la siguiente página y la añade a los items existentes.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    final result = await _fetchPage(
      query: arg,
      page: current.page + 1,
      existing: current.items,
    );

    state = AsyncData(result);
  }

  /// Recarga desde la primera página con los parámetros actuales.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _fetchPage(query: arg, page: 1, existing: const []),
    );
  }

  Future<CatalogState> _fetchPage({
    required CatalogQuery query,
    required int page,
    required List<MaterialItem> existing,
  }) async {
    final useCase = ref.read(browseCatalogUseCaseProvider);
    final result = await useCase(BrowseCatalogParams(
      cat: query.cat,
      programaId: query.programaId,
      q: query.q,
      page: page,
      pageSize: _pageSize,
    ));

    return result.fold(
      (failure) => CatalogState(
        items: existing,
        page: page,
        errorMessage: failure.message,
      ),
      (newItems) {
        final all = [...existing, ...newItems];
        return CatalogState(
          items: all,
          total: all.length, // approximate; backend total not exposed by repo
          page: page,
          hasMore: newItems.length == _pageSize,
        );
      },
    );
  }
}

/// Provider family del catálogo indexado por [CatalogQuery].
///
/// Uso:
/// ```dart
/// final state = ref.watch(catalogProvider(CatalogQuery(q: 'camisa')));
/// ```
final catalogProvider = AsyncNotifierProvider.autoDispose
    .family<CatalogNotifier, CatalogState, CatalogQuery>(
  CatalogNotifier.new,
);
