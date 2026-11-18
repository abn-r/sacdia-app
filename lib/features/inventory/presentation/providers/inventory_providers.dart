import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/keep_alive_during.dart';
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
import '../../domain/usecases/upload_inventory_evidence.dart';

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

final uploadInventoryEvidenceUseCaseProvider =
    Provider<UploadInventoryEvidence>((ref) {
  return UploadInventoryEvidence(ref.read(inventoryRepositoryProvider));
});

final getInventoryCategoriesUseCaseProvider =
    Provider<GetInventoryCategories>((ref) {
  return GetInventoryCategories(ref.read(inventoryRepositoryProvider));
});

// ── Club context helpers ────────────────────────────────────────────────────────

/// The inventory endpoint is named `/clubs/:clubId/inventory`, but the RBAC
/// resource behind it resolves that path segment as `club_sections.club_section_id`.
/// Using the main club id here causes `GUARD_CLUB_SCOPE_REQUIRED` for valid
/// users whose active assignment belongs to another section id.
int? inventoryResourceIdFromContext(ClubContext? context) => context?.sectionId;

/// Obtiene el identificador de la sección activa para el recurso de inventario.
final inventoryClubIdProvider = FutureProvider.autoDispose<int?>((ref) async {
  final context = await ref.watch(clubContextProvider.future);
  return inventoryResourceIdFromContext(context);
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
    (failure) => throw failure,
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
    (failure) => throw failure,
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
    (failure) => throw failure,
    (item) => item,
  );
});

// ── Search & filter state ───────────────────────────────────────────────────────

class InventoryFilters {
  final String searchQuery;

  /// Categorías marcadas en la hoja de filtros (varias a la vez).
  final Set<int> categoryIds;
  final ItemCondition? condition;
  final InventorySortOrder sortOrder;

  const InventoryFilters({
    this.searchQuery = '',
    this.categoryIds = const {},
    this.condition,
    this.sortOrder = InventorySortOrder.nameAsc,
  });

  InventoryFilters copyWith({
    String? searchQuery,
    Set<int>? categoryIds,
    bool clearCategories = false,
    ItemCondition? condition,
    bool clearCondition = false,
    InventorySortOrder? sortOrder,
  }) {
    return InventoryFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      categoryIds:
          clearCategories ? const {} : (categoryIds ?? this.categoryIds),
      condition: clearCondition ? null : (condition ?? this.condition),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  bool get hasActiveFilters =>
      searchQuery.isNotEmpty || categoryIds.isNotEmpty || condition != null;

  /// Filtros que viven en la hoja: una cuenta por categoría marcada y una más
  /// si el orden no es el predeterminado. El estado vive en los chips de la
  /// lista y la búsqueda en su campo, por eso no cuentan aquí.
  int get sheetFilterCount =>
      categoryIds.length + (sortOrder == InventorySortOrder.nameAsc ? 0 : 1);

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
      if (categoryIds.isNotEmpty && !categoryIds.contains(item.category.id)) {
        return false;
      }
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
        return 'inventory.filter.sort_name_asc'.tr();
      case InventorySortOrder.nameDesc:
        return 'inventory.filter.sort_name_desc'.tr();
      case InventorySortOrder.newest:
        return 'inventory.filter.sort_newest'.tr();
      case InventorySortOrder.oldest:
        return 'inventory.filter.sort_oldest'.tr();
      case InventorySortOrder.valueDesc:
        return 'inventory.filter.sort_value_desc'.tr();
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

// ── Derived data for chips and the filter sheet ─────────────────────────────────

/// Cuántos artículos hay por estado, con la búsqueda y las categorías ya
/// aplicadas (el propio estado no cuenta, para que cada chip muestre lo que
/// saldría al tocarlo).
class InventoryConditionCounts {
  final int total;
  final Map<ItemCondition, int> byCondition;

  const InventoryConditionCounts({
    this.total = 0,
    this.byCondition = const {},
  });

  /// `null` pide el total ("Todos").
  int of(ItemCondition? condition) =>
      condition == null ? total : (byCondition[condition] ?? 0);
}

final inventoryConditionCountsProvider =
    Provider.autoDispose<InventoryConditionCounts>((ref) {
  final items = ref.watch(inventoryItemsProvider).value ?? const [];
  final filters = ref.watch(inventoryFiltersProvider);
  final scoped = filters.copyWith(clearCondition: true).applyTo(items);
  return InventoryConditionCounts(
    total: scoped.length,
    byCondition: {
      for (final condition in ItemCondition.values)
        condition: scoped.where((i) => i.condition == condition).length,
    },
  );
});

/// Una categoría de la hoja de filtros y cuántos artículos tiene.
class InventoryCategoryOption {
  final InventoryCategory category;
  final int count;

  const InventoryCategoryOption({required this.category, required this.count});
}

/// Categorías que aparecen en el inventario cargado (no depende del catálogo
/// del servidor), con su conteo bajo la búsqueda y el estado activos. Una
/// categoría marcada sigue visible aunque su conteo caiga a cero.
final inventoryCategoryOptionsProvider =
    Provider.autoDispose<List<InventoryCategoryOption>>((ref) {
  final items = ref.watch(inventoryItemsProvider).value ?? const [];
  final filters = ref.watch(inventoryFiltersProvider);
  final scoped = filters.copyWith(clearCategories: true).applyTo(items);

  final categories = <int, InventoryCategory>{
    for (final item in items) item.category.id: item.category,
  };
  final counts = <int, int>{};
  for (final item in scoped) {
    counts[item.category.id] = (counts[item.category.id] ?? 0) + 1;
  }

  final options = [
    for (final category in categories.values)
      InventoryCategoryOption(
        category: category,
        count: counts[category.id] ?? 0,
      ),
  ]..sort((a, b) =>
      a.category.name.toLowerCase().compareTo(b.category.name.toLowerCase()));
  return options;
});

// ── Item form notifier ──────────────────────────────────────────────────────────

class InventoryItemFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool success;
  final InventoryItem? savedItem;

  const InventoryItemFormState({
    this.isLoading = false,
    this.errorMessage,
    this.success = false,
    this.savedItem,
  });

  InventoryItemFormState copyWith({
    bool? isLoading,
    String? errorMessage,
    bool? success,
    InventoryItem? savedItem,
    bool clearSavedItem = false,
  }) {
    return InventoryItemFormState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      success: success ?? this.success,
      savedItem: clearSavedItem ? null : (savedItem ?? this.savedItem),
    );
  }
}

class InventoryItemFormNotifier extends Notifier<InventoryItemFormState> {
  @override
  InventoryItemFormState build() => const InventoryItemFormState();

  Future<bool> save({
    required int clubId,
    required String instanceType,
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
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      success: false,
      clearSavedItem: true,
    );

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
        (item) {
          state = state.copyWith(
            isLoading: false,
            success: true,
            savedItem: item,
          );
          ref.invalidate(inventoryItemsProvider);
          ref.invalidate(inventoryItemDetailProvider(existingId));
          return true;
        },
      );
    } else {
      final result = await ref.read(createInventoryItemUseCaseProvider)(
        CreateInventoryItemParams(
          clubId: clubId,
          instanceType: instanceType,
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
        (item) {
          state = state.copyWith(
            isLoading: false,
            success: true,
            savedItem: item,
          );
          ref.invalidate(inventoryItemsProvider);
          return true;
        },
      );
    }
  }

  Future<bool> uploadEvidence({
    required int itemId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      success: false,
    );

    final result = await ref.read(uploadInventoryEvidenceUseCaseProvider)(
      UploadInventoryEvidenceParams(
        itemId: itemId,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
      ),
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: failure.message,
          success: false,
        );
        return false;
      },
      (_) {
        state = state.copyWith(isLoading: false, success: true);
        ref.invalidate(inventoryItemsProvider);
        ref.invalidate(inventoryItemDetailProvider(itemId));
        return true;
      },
    );
  }

  void reset() => state = const InventoryItemFormState();
}

final inventoryItemFormNotifierProvider = NotifierProvider.autoDispose<
    InventoryItemFormNotifier, InventoryItemFormState>(
  InventoryItemFormNotifier.new,
);

// ── Change-condition notifier ───────────────────────────────────────────────────

class InventoryConditionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Cambia solo el estado de [item]. El PATCH trata un campo opcional en null
  /// como "borrarlo", así que se reenvía el resto del artículo tal cual.
  Future<bool> change(InventoryItem item, ItemCondition condition) =>
      // Callers only `ref.read` this notifier (see keepAliveDuring).
      ref.keepAliveDuring(() async {
        state = true;
        final result = await ref.read(updateInventoryItemUseCaseProvider)(
          UpdateInventoryItemParams(
            itemId: item.id,
            name: item.name,
            categoryId: item.category.id,
            quantity: item.quantity,
            condition: condition,
            description: item.description,
            serialNumber: item.serialNumber,
            purchaseDate: item.purchaseDate,
            estimatedValue: item.estimatedValue,
            location: item.location,
            assignedTo: item.assignedTo,
            notes: item.notes,
          ),
        );
        return result.fold<bool>(
          (_) {
            state = false;
            return false;
          },
          (_) {
            state = false;
            ref.invalidate(inventoryItemsProvider);
            ref.invalidate(inventoryItemDetailProvider(item.id));
            return true;
          },
        );
      });
}

final inventoryConditionNotifierProvider =
    NotifierProvider.autoDispose<InventoryConditionNotifier, bool>(
  InventoryConditionNotifier.new,
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

class InventoryDeleteNotifier extends Notifier<InventoryDeleteState> {
  @override
  InventoryDeleteState build() => const InventoryDeleteState();

  Future<bool> deleteItem(int itemId) =>
      // Callers only `ref.read` this notifier: keep it alive until the request
      // settles (see keepAliveDuring).
      ref.keepAliveDuring(() async {
        state = const InventoryDeleteState(isLoading: true);

        final result = await ref.read(deleteInventoryItemUseCaseProvider)(
          DeleteInventoryItemParams(itemId: itemId),
        );

        return result.fold<bool>(
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
      });
}

final inventoryDeleteNotifierProvider =
    NotifierProvider.autoDispose<InventoryDeleteNotifier, InventoryDeleteState>(
  InventoryDeleteNotifier.new,
);
