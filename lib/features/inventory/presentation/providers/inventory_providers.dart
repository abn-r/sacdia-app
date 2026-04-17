import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/dio_provider.dart';
import '../../../auth/domain/utils/authorization_utils.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../data/datasources/inventory_remote_data_source.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/entities/inventory_category.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../../domain/usecases/create_inventory_item.dart';
import '../../domain/usecases/delete_inventory_item.dart';
import '../../domain/usecases/get_inventory_categories.dart';
import '../../domain/usecases/get_inventory_item.dart';
import '../../domain/usecases/get_inventory_items.dart';
import '../../domain/usecases/update_inventory_item.dart';

// ── Infrastructure ──────────────────────────────────────────────────────────────

final inventoryRemoteDataSourceProvider =
    Provider<InventoryRemoteDataSource>((ref) {
  return InventoryRemoteDataSourceImpl(
    dio: ref.read(dioProvider),
    baseUrl: ref.read(apiBaseUrlProvider),
  );
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(
    remoteDataSource: ref.read(inventoryRemoteDataSourceProvider),
    networkInfo: ref.read(networkInfoProvider),
  );
});

// ── Use cases ───────────────────────────────────────────────────────────────────

final getInventoryItemsUseCaseProvider = Provider<GetInventoryItems>((ref) {
  return GetInventoryItems(ref.read(inventoryRepositoryProvider));
});

final getInventoryItemUseCaseProvider = Provider<GetInventoryItem>((ref) {
  return GetInventoryItem(ref.read(inventoryRepositoryProvider));
});

final createInventoryItemUseCaseProvider = Provider<CreateInventoryItem>((ref) {
  return CreateInventoryItem(ref.read(inventoryRepositoryProvider));
});

final updateInventoryItemUseCaseProvider = Provider<UpdateInventoryItem>((ref) {
  return UpdateInventoryItem(ref.read(inventoryRepositoryProvider));
});

final deleteInventoryItemUseCaseProvider = Provider<DeleteInventoryItem>((ref) {
  return DeleteInventoryItem(ref.read(inventoryRepositoryProvider));
});

final getInventoryCategoriesUseCaseProvider =
    Provider<GetInventoryCategories>((ref) {
  return GetInventoryCategories(ref.read(inventoryRepositoryProvider));
});

// ── Club context helpers ────────────────────────────────────────────────────────

/// Obtiene el clubId del contexto activo del usuario.
final inventoryClubIdProvider = FutureProvider.autoDispose<int?>((ref) async {
  final context = await ref.watch(clubContextProvider.future);
  return context?.clubId;
});

/// Maps the human-readable club type name to the backend instanceType query
/// param expected by GET /inventory/clubs/:clubId/inventory.
String mapClubTypeToInstanceType(String? clubTypeName) {
  switch (clubTypeName?.toLowerCase()) {
    case 'aventureros':
      return 'adv';
    case 'conquistadores':
      return 'pathf';
    case 'guías mayores':
    case 'guias mayores':
      return 'mg';
    default:
      return 'pathf'; // safe default
  }
}

/// Derives the instanceType string from the active club context.
final inventoryInstanceTypeProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final context = await ref.watch(clubContextProvider.future);
  return mapClubTypeToInstanceType(context?.clubTypeName);
});

// ── Permission helper ───────────────────────────────────────────────────────────

/// Devuelve true si el usuario puede gestionar el inventario.
final canManageInventoryProvider =
    FutureProvider.autoDispose<bool>((ref) async {
  final authState = await ref.watch(authNotifierProvider.future);
  if (authState == null) return false;

  return hasAnyPermission(authState, const {
    'inventory:create',
    'inventory:update',
    'inventory:delete',
  });
});

// ── Categories ──────────────────────────────────────────────────────────────────

final inventoryCategoriesProvider =
    FutureProvider.autoDispose<List<InventoryCategory>>((ref) async {
  final useCase = ref.read(getInventoryCategoriesUseCaseProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await useCase(cancelToken: cancelToken);
  return result.fold(
    (failure) => throw Exception(failure.message),
    (cats) => cats,
  );
});

// ── Inventory list ──────────────────────────────────────────────────────────────

final inventoryItemsProvider =
    FutureProvider.autoDispose<List<InventoryItem>>((ref) async {
  final clubId = await ref.watch(inventoryClubIdProvider.future);
  if (clubId == null) return [];

  final instanceType = await ref.watch(inventoryInstanceTypeProvider.future);

  final useCase = ref.read(getInventoryItemsUseCaseProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await useCase(
    GetInventoryItemsParams(clubId: clubId, instanceType: instanceType),
    cancelToken: cancelToken,
  );

  return result.fold(
    (failure) => throw Exception(failure.message),
    (items) => items,
  );
});

// ── Inventory item detail ───────────────────────────────────────────────────────

final inventoryItemDetailProvider =
    FutureProvider.autoDispose.family<InventoryItem, int>((ref, itemId) async {
  final repo = ref.read(inventoryRepositoryProvider);
  final cancelToken = CancelToken();
  ref.onDispose(() => cancelToken.cancel());
  final result = await repo.getItem(
    itemId: itemId,
    cancelToken: cancelToken,
  );
  return result.fold(
    (failure) => throw Exception(failure.message),
    (item) => item,
  );
});

// ── Search & filter state ───────────────────────────────────────────────────────

class InventoryFilters {
  final String searchQuery;
  final int? categoryId;
  final ItemCondition? condition;
  final InventorySortOrder sortOrder;

  const InventoryFilters({
    this.searchQuery = '',
    this.categoryId,
    this.condition,
    this.sortOrder = InventorySortOrder.nameAsc,
  });

  InventoryFilters copyWith({
    String? searchQuery,
    int? categoryId,
    bool clearCategory = false,
    ItemCondition? condition,
    bool clearCondition = false,
    InventorySortOrder? sortOrder,
  }) {
    return InventoryFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      condition: clearCondition ? null : (condition ?? this.condition),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty || categoryId != null || condition != null;

  List<InventoryItem> applyTo(List<InventoryItem> items) {
    var result = items.where((item) {
      // Búsqueda por nombre/descripción
      if (searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        final nameMatch = item.name.toLowerCase().contains(query);
        final descMatch =
            item.description?.toLowerCase().contains(query) ?? false;
        if (!nameMatch && !descMatch) return false;
      }
      // Filtro por categoría
      if (categoryId != null && item.category.id != categoryId) return false;
      // Filtro por condición
      if (condition != null && item.condition != condition) return false;
      return true;
    }).toList();

    // Ordenamiento
    switch (sortOrder) {
      case InventorySortOrder.nameAsc:
        result.sort((a, b) => a.name.compareTo(b.name));
      case InventorySortOrder.nameDesc:
        result.sort((a, b) => b.name.compareTo(a.name));
      case InventorySortOrder.newest:
        result.sort((a, b) => b.registeredAt.compareTo(a.registeredAt));
      case InventorySortOrder.oldest:
        result.sort((a, b) => a.registeredAt.compareTo(b.registeredAt));
      case InventorySortOrder.valueDesc:
        result.sort((a, b) {
          final av = a.estimatedValue ?? 0;
          final bv = b.estimatedValue ?? 0;
          return bv.compareTo(av);
        });
    }

    return result;
  }
}

enum InventorySortOrder {
  nameAsc,
  nameDesc,
  newest,
  oldest,
  valueDesc;

  String get label {
    switch (this) {
      case InventorySortOrder.nameAsc:
        return 'Nombre A-Z';
      case InventorySortOrder.nameDesc:
        return 'Nombre Z-A';
      case InventorySortOrder.newest:
        return 'Más recientes';
      case InventorySortOrder.oldest:
        return 'Más antiguos';
      case InventorySortOrder.valueDesc:
        return 'Mayor valor';
    }
  }
}

final inventoryFiltersProvider = StateProvider.autoDispose<InventoryFilters>(
    (ref) => const InventoryFilters());

final filteredInventoryItemsProvider =
    Provider.autoDispose<AsyncValue<List<InventoryItem>>>((ref) {
  final itemsAsync = ref.watch(inventoryItemsProvider);
  final filters = ref.watch(inventoryFiltersProvider);

  return itemsAsync.whenData((items) => filters.applyTo(items));
});

// ── Inventory summary stats ─────────────────────────────────────────────────────

class InventorySummary {
  final int totalItems;
  final double totalValue;
  final int buenoCount;
  final int regularCount;
  final int maloCount;

  const InventorySummary({
    required this.totalItems,
    required this.totalValue,
    required this.buenoCount,
    required this.regularCount,
    required this.maloCount,
  });
}

final inventorySummaryProvider = Provider.autoDispose<InventorySummary?>((ref) {
  final itemsAsync = ref.watch(inventoryItemsProvider);
  return itemsAsync.valueOrNull.map((items) {
    return InventorySummary(
      totalItems: items.length,
      totalValue: items.fold(0.0, (sum, i) => sum + (i.estimatedValue ?? 0)),
      buenoCount: items.where((i) => i.condition == ItemCondition.bueno).length,
      regularCount:
          items.where((i) => i.condition == ItemCondition.regular).length,
      maloCount: items.where((i) => i.condition == ItemCondition.malo).length,
    );
  });
});

extension _Nullable<T> on T? {
  R? map<R>(R Function(T) f) => this == null ? null : f(this as T);
}

// ── Item form notifier ──────────────────────────────────────────────────────────

class InventoryItemFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const InventoryItemFormState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });

  InventoryItemFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
  }) {
    return InventoryItemFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
    );
  }
}

class InventoryItemFormNotifier extends AutoDisposeNotifier<InventoryItemFormState> {
  @override
  InventoryItemFormState build() => const InventoryItemFormState();

  Future<bool> save({
    required int clubId,
    required String name,
    required int categoryId,
    required int quantity,
    required ItemCondition condition,
    String? description,
    String? serialNumber,
    DateTime? purchaseDate,
    double? estimatedValue,
    String? location,
    String? assignedTo,
    String? notes,
    int? existingId, // non-null → update
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, success: false);

    if (existingId != null) {
      final result = await ref.read(updateInventoryItemUseCaseProvider)(
        UpdateInventoryItemParams(
          itemId: existingId,
          name: name,
          categoryId: categoryId,
          quantity: quantity,
          condition: condition,
          description: description,
          serialNumber: serialNumber,
          purchaseDate: purchaseDate,
          estimatedValue: estimatedValue,
          location: location,
          assignedTo: assignedTo,
          notes: notes,
        ),
      );

      return result.fold(
        (failure) {
          state =
              state.copyWith(isLoading: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isLoading: false, success: true);
          ref.invalidate(inventoryItemsProvider);
          return true;
        },
      );
    } else {
      final result = await ref.read(createInventoryItemUseCaseProvider)(
        CreateInventoryItemParams(
          clubId: clubId,
          name: name,
          categoryId: categoryId,
          quantity: quantity,
          condition: condition,
          description: description,
          serialNumber: serialNumber,
          purchaseDate: purchaseDate,
          estimatedValue: estimatedValue,
          location: location,
          assignedTo: assignedTo,
          notes: notes,
        ),
      );

      return result.fold(
        (failure) {
          state =
              state.copyWith(isLoading: false, errorMessage: failure.message);
          return false;
        },
        (_) {
          state = state.copyWith(isLoading: false, success: true);
          ref.invalidate(inventoryItemsProvider);
          return true;
        },
      );
    }
  }

  void reset() => state = const InventoryItemFormState();
}

final inventoryItemFormNotifierProvider = NotifierProvider.autoDispose<
    InventoryItemFormNotifier, InventoryItemFormState>(
  InventoryItemFormNotifier.new,
);

// ── Delete notifier ─────────────────────────────────────────────────────────────

class InventoryDeleteState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;

  const InventoryDeleteState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
  });
}

class InventoryDeleteNotifier extends AutoDisposeNotifier<InventoryDeleteState> {
  @override
  InventoryDeleteState build() => const InventoryDeleteState();

  Future<bool> deleteItem(int itemId) async {
    state = const InventoryDeleteState(isLoading: true);

    final result = await ref.read(deleteInventoryItemUseCaseProvider)(
      DeleteInventoryItemParams(itemId: itemId),
    );

    return result.fold(
      (failure) {
        state = InventoryDeleteState(errorMessage: failure.message);
        return false;
      },
      (_) {
        state = const InventoryDeleteState(success: true);
        ref.invalidate(inventoryItemsProvider);
        return true;
      },
    );
  }
}

final inventoryDeleteNotifierProvider = NotifierProvider.autoDispose<
    InventoryDeleteNotifier, InventoryDeleteState>(
  InventoryDeleteNotifier.new,
);
