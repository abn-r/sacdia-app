import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/comprobante.dart';
import '../../domain/entities/material_category.dart';
import '../../domain/entities/material_config.dart';
import '../../domain/entities/material_entrega.dart';
import '../../domain/entities/material_item.dart';
import '../../domain/entities/material_programa.dart';
import '../../domain/entities/orden.dart';
import '../../domain/repositories/materiales_repository.dart';
import '../datasources/materiales_remote_data_source.dart';

/// Implementación concreta del [MaterialesRepository].
///
/// Delega llamadas de red al [MaterialesRemoteDataSource] y convierte
/// excepciones en valores de tipo [Either<Failure, T>].
class MaterialesRepositoryImpl implements MaterialesRepository {
  final MaterialesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  MaterialesRepositoryImpl({
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
  Future<Either<Failure, List<MaterialCategory>>> listCategorias() async {
    try {
      final models = await remoteDataSource.listCategorias();
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
  Future<Either<Failure, List<MaterialPrograma>>> listProgramas() async {
    try {
      final models = await remoteDataSource.listProgramas();
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
  Future<Either<Failure, Orden>> createOrder({
    required int clubSectionId,
    required List<({String productId, String? variantOptionId, int qty})> lines,
    required MaterialEntrega entrega,
    String? notas,
  }) async {
    try {
      final model = await remoteDataSource.createOrder(
        clubSectionId: clubSectionId,
        lines: lines,
        entrega: entrega,
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
  Future<Either<Failure, List<Orden>>> listOrdenes({
    String? estado,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final models = await remoteDataSource.listOrdenes(
        estado: estado,
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
  Future<Either<Failure, List<Orden>>> getOrderHistory({
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
  Future<Either<Failure, Orden>> getOrderByFolio(String folioOrId) async {
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
  Future<Either<Failure, Orden>> cancelOrder(
      String folioOrId, String reason) async {
    try {
      final model =
          await remoteDataSource.cancelOrder(folioOrId, reason);
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

  // ── Comprobantes ──────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Comprobante>>> listComprobantes(
      String folioOrId) async {
    try {
      final models =
          await remoteDataSource.listComprobantes(folioOrId);
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
  Future<Either<Failure, Comprobante>> uploadComprobante({
    required String folioOrId,
    required File file,
    required int montoCentavos,
    required String refBancariaDeclarada,
    required DateTime fechaPago,
    void Function(double)? onProgress,
  }) async {
    try {
      final model = await remoteDataSource.uploadComprobante(
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
