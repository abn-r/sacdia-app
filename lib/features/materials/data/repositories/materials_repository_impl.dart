import 'dart:io';

import 'package:dartz/dartz.dart' hide Order;

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/entities/material_category.dart';
import '../../domain/entities/material_config.dart';
import '../../domain/entities/material_delivery.dart';
import '../../domain/entities/material_item.dart';
import '../../domain/entities/material_program.dart';
import '../../domain/entities/order.dart';
import '../../domain/repositories/materials_repository.dart';
import '../datasources/materials_remote_data_source.dart';

/// Implementación concreta del [MaterialsRepository].
///
/// Delega llamadas de red al [MaterialsRemoteDataSource] y convierte
/// excepciones en valores de tipo [Either<Failure, T>].
class MaterialsRepositoryImpl implements MaterialsRepository {
  final MaterialsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MaterialsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Catálogo ───────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<MaterialItem>>> browseCatalog({
    String? cat,
    int? programaId,
    String? q,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final models = await remoteDataSource.browseCatalog(
        cat: cat,
        programaId: programaId,
        q: q,
        page: page,
        pageSize: pageSize,
      );
      return Right(models.map((m) => m.toEntity()).toList());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, MaterialItem>> getProductDetail(String id) async {
    try {
      final model = await remoteDataSource.getProductDetail(id);
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<MaterialCategory>>> listCategories() async {
    try {
      final models = await remoteDataSource.listCategories();
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
  Future<Either<Failure, List<MaterialProgram>>> listPrograms() async {
    try {
      final models = await remoteDataSource.listPrograms();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── Órdenes ────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, Order>> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialDelivery delivery,
    String? notas,
  }) async {
    try {
      final model = await remoteDataSource.createOrder(
        clubSectionId: clubSectionId,
        lines: lines,
        delivery: delivery,
        notas: notas,
      );
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Order>>> listOrders({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final models = await remoteDataSource.listOrders(
        status: status,
        page: page,
        pageSize: pageSize,
      );
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
  Future<Either<Failure, List<Order>>> getOrderHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final models = await remoteDataSource.getOrderHistory(
        page: page,
        pageSize: pageSize,
      );
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
  Future<Either<Failure, Order>> getOrderByFolio(String folioOrId) async {
    try {
      final model = await remoteDataSource.getOrderByFolio(folioOrId);
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Order>> cancelOrder(
      String folioOrId, String reason) async {
    try {
      final model = await remoteDataSource.cancelOrder(folioOrId, reason);
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── Receipts ──────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Receipt>>> listReceipts(
      String folioOrId) async {
    try {
      final models = await remoteDataSource.listReceipts(folioOrId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Receipt>> uploadReceipt({
    required String folioOrId,
    required File file,
    required int montoCentavos,
    required String refBancariaDeclarada,
    required DateTime fechaPago,
    void Function(double)? onProgress,
  }) async {
    try {
      final model = await remoteDataSource.uploadReceipt(
        folioOrId: folioOrId,
        file: file,
        montoCentavos: montoCentavos,
        refBancariaDeclarada: refBancariaDeclarada,
        fechaPago: fechaPago,
        onProgress: onProgress,
      );
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      return Left(NotFoundFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }

  // ── Configuración ──────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, MaterialConfig>> getConfig() async {
    try {
      final model = await remoteDataSource.getConfig();
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
