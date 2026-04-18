import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/active_session.dart';
import '../../domain/repositories/active_sessions_repository.dart';
import '../datasources/active_sessions_remote_data_source.dart';

/// Implementación del repositorio de sesiones activas.
///
/// Sin caché local por diseño: la lista de sesiones debe reflejar
/// siempre el estado server-side por seguridad.
class ActiveSessionsRepositoryImpl implements ActiveSessionsRepository {
  final ActiveSessionsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  static const _tag = 'ActiveSessionsRepo';

  ActiveSessionsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<ActiveSession>>> list() async {
    final hasConnection = await networkInfo.isConnected;

    if (!hasConnection) {
      AppLogger.w('Sin red — no se puede cargar sesiones activas', tag: _tag);
      return const Left(
        NetworkFailure(message: 'Sin conexión. Verificá tu red e intentá de nuevo.'),
      );
    }

    try {
      final sessions = await remoteDataSource.getSessions();
      return Right(sessions);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error del servidor al obtener sesiones: ${e.message}',
        tag: _tag,
      );
      return Left(ServerFailure(message: e.message, code: e.code));
    } on DioException catch (e) {
      AppLogger.w('DioException al obtener sesiones', tag: _tag, error: e);
      return Left(NetworkFailure(
        message: 'Error de red al obtener sesiones.',
        code: e.response?.statusCode,
      ));
    } catch (e) {
      AppLogger.e('Error inesperado al obtener sesiones', tag: _tag, error: e);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> revoke(String sessionId) async {
    final hasConnection = await networkInfo.isConnected;

    if (!hasConnection) {
      return const Left(
        NetworkFailure(message: 'Sin conexión. No se pudo revocar la sesión.'),
      );
    }

    try {
      await remoteDataSource.revokeSession(sessionId);
      return const Right(null);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error al revocar sesión $sessionId: ${e.message}',
        tag: _tag,
      );
      return Left(ServerFailure(message: e.message, code: e.code));
    } on DioException catch (e) {
      AppLogger.w('DioException al revocar sesión', tag: _tag, error: e);
      return Left(NetworkFailure(
        message: 'Error de red al revocar sesión.',
        code: e.response?.statusCode,
      ));
    } catch (e) {
      AppLogger.e('Error inesperado al revocar sesión', tag: _tag, error: e);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> revokeAllOthers() async {
    final hasConnection = await networkInfo.isConnected;

    if (!hasConnection) {
      return const Left(
        NetworkFailure(message: 'Sin conexión. No se pudieron revocar las sesiones.'),
      );
    }

    try {
      final count = await remoteDataSource.revokeAllOtherSessions();
      return Right(count);
    } on ServerException catch (e) {
      AppLogger.w(
        'Error al revocar todas las sesiones: ${e.message}',
        tag: _tag,
      );
      return Left(ServerFailure(message: e.message, code: e.code));
    } on DioException catch (e) {
      AppLogger.w('DioException al revocar todas las sesiones', tag: _tag, error: e);
      return Left(NetworkFailure(
        message: 'Error de red al revocar sesiones.',
        code: e.response?.statusCode,
      ));
    } catch (e) {
      AppLogger.e('Error inesperado al revocar sesiones', tag: _tag, error: e);
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }
}
