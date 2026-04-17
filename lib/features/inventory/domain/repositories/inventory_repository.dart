import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/failures.dart';
import '../entities/inventory_category.dart';
import '../entities/inventory_item.dart';

/// Contrato de acceso a datos del inventario del club.
abstract class InventoryRepository {
  /// Devuelve los ítems del inventario del club.
  Future<Either<Failure, List<InventoryItem>>> getItems({
    required int clubId,
    required String instanceType,
    CancelToken? cancelToken,
  });

  /// Devuelve un ítem por su ID.
  Future<Either<Failure, InventoryItem>> getItem({
    required int itemId,
    CancelToken? cancelToken,
  });

  /// Crea un nuevo ítem en el inventario.
  Future<Either<Failure, InventoryItem>> createItem({
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
  });

  /// Actualiza un ítem existente.
  Future<Either<Failure, InventoryItem>> updateItem({
    required int itemId,
    String? name,
    int? categoryId,
    int? quantity,
    ItemCondition? condition,
    String? description,
    String? serialNumber,
    DateTime? purchaseDate,
    double? estimatedValue,
    String? location,
    String? assignedTo,
    String? notes,
  });

  /// Elimina (soft-delete) un ítem del inventario.
  Future<Either<Failure, void>> deleteItem({required int itemId});

  /// Devuelve las categorías de inventario disponibles.
  Future<Either<Failure, List<InventoryCategory>>> getCategories({
    CancelToken? cancelToken,
  });
}
