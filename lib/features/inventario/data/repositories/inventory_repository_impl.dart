import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/inventory_category.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_data_source.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  InventoryRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<InventoryItem>>> getItems(
      {required int clubId}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final models = await remoteDataSource.getItems(clubId: clubId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, InventoryItem>> getItem(
      {required int itemId}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.getItem(itemId: itemId);
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
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.createItem(
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
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.updateItem(
        itemId: itemId,
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
  Future<Either<Failure, void>> deleteItem({required int itemId}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      await remoteDataSource.deleteItem(itemId: itemId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<InventoryCategory>>> getCategories() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final models = await remoteDataSource.getCategories();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
