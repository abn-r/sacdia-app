import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/data_export.dart';
import '../../domain/repositories/data_export_repository.dart';
import '../datasources/data_export_remote_data_source.dart';

/// Implementación del repositorio de exportaciones de datos.
///
/// Sin caché local por diseño: los statuses cambian rápido y la información
/// es sensible — siempre se consulta el estado real del servidor.
class DataExportRepositoryImpl implements DataExportRepository {
  final DataExportRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  static const _tag = 'DataExportRepo';

  DataExportRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, DataExport>> request() async {
    final hasConnection = await networkInfo.isConnected;

    if (!hasConnection) {
      AppLogger.w('Sin red — no se puede solicitar exportación', tag: _tag);
      return Left(
        NetworkFailure(
          message: tr('profile.data_export.errors.no_connection'),
        ),
      );
    }

    try {
      final export = await remoteDataSource.requestExport();
      return Right(export);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error del servidor al solicitar exportación: ${e.message}',
        tag: _tag,
      );
      return Left(ServerFailure(message: e.message, code: e.code));
    } on DioException catch (e) {
      AppLogger.w('DioException al solicitar exportación', tag: _tag, error: e);
      return Left(NetworkFailure(
        message: tr('profile.data_export.errors.no_connection'),
        code: e.response?.statusCode,
      ));
    } catch (e) {
      AppLogger.e('Error inesperado al solicitar exportación', tag: _tag, error: e);
      return Left(ServerFailure(message: tr('profile.data_export.errors.unexpected', namedArgs: {'detail': '$e'})));
    }
  }

  @override
  Future<Either<Failure, List<DataExport>>> list() async {
    final hasConnection = await networkInfo.isConnected;

    if (!hasConnection) {
      AppLogger.w('Sin red — no se puede listar exportaciones', tag: _tag);
      return Left(
        NetworkFailure(
          message: tr('profile.data_export.errors.no_connection'),
        ),
      );
    }

    try {
      final exports = await remoteDataSource.getExports();
      return Right(exports);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error del servidor al listar exportaciones: ${e.message}',
        tag: _tag,
      );
      return Left(ServerFailure(message: e.message, code: e.code));
    } on DioException catch (e) {
      AppLogger.w('DioException al listar exportaciones', tag: _tag, error: e);
      return Left(NetworkFailure(
        message: tr('profile.data_export.errors.no_connection'),
        code: e.response?.statusCode,
      ));
    } catch (e) {
      AppLogger.e('Error inesperado al listar exportaciones', tag: _tag, error: e);
      return Left(ServerFailure(message: tr('profile.data_export.errors.unexpected', namedArgs: {'detail': '$e'})));
    }
  }

  @override
  Future<Either<Failure, String>> getDownloadUrl(String exportId) async {
    final hasConnection = await networkInfo.isConnected;

    if (!hasConnection) {
      return Left(
        NetworkFailure(
          message: tr('profile.data_export.errors.no_connection'),
        ),
      );
    }

    try {
      final url = await remoteDataSource.getDownloadUrl(exportId);
      return Right(url);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error al obtener URL de descarga $exportId: ${e.message}',
        tag: _tag,
      );
      return Left(ServerFailure(message: e.message, code: e.code));
    } on DioException catch (e) {
      AppLogger.w(
        'DioException al obtener URL de descarga',
        tag: _tag,
        error: e,
      );
      return Left(NetworkFailure(
        message: tr('profile.data_export.errors.no_connection'),
        code: e.response?.statusCode,
      ));
    } catch (e) {
      AppLogger.e(
        'Error inesperado al obtener URL de descarga',
        tag: _tag,
        error: e,
      );
      return Left(ServerFailure(message: tr('profile.data_export.errors.unexpected', namedArgs: {'detail': '$e'})));
    }
  }
}
