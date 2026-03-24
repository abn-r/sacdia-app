import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/role_assignment.dart';
import '../../domain/repositories/role_assignments_repository.dart';
import '../datasources/role_assignments_remote_data_source.dart';

/// Implementación del repositorio de asignaciones de rol
class RoleAssignmentsRepositoryImpl implements RoleAssignmentsRepository {
  final RoleAssignmentsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  RoleAssignmentsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  Future<bool> get _isConnected => networkInfo.isConnected;

  Left<Failure, T> _networkFailure<T>() =>
      const Left(NetworkFailure(message: 'No hay conexion a internet'));

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  @override
  Future<Either<Failure, List<RoleAssignment>>> getAssignments() async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models = await remoteDataSource.getAssignments();
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
