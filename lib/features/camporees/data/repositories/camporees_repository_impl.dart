import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/camporee.dart';
import '../../domain/entities/camporee_member.dart';
import '../../domain/repositories/camporees_repository.dart';
import '../datasources/camporees_remote_data_source.dart';

/// Implementación del repositorio de camporees.
class CamporeesRepositoryImpl implements CamporeesRepository {
  final CamporeesRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CamporeesRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Future<bool> get _isConnected => networkInfo.isConnected;

  Left<Failure, T> _networkFailure<T>() =>
      const Left(NetworkFailure(message: 'No hay conexion a internet'));

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── Métodos ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Camporee>>> getCamporees({bool? active}) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models = await remoteDataSource.getCamporees(active: active);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, Camporee>> getCamporeeDetail(int camporeeId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.getCamporeeDetail(camporeeId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, CamporeeMember>> registerMember(
    int camporeeId, {
    required String userId,
    required String camporeeType,
    String? clubName,
    int? insuranceId,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.registerMember(
        camporeeId,
        userId: userId,
        camporeeType: camporeeType,
        clubName: clubName,
        insuranceId: insuranceId,
      );
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<CamporeeMember>>> getCamporeeMembers(
      int camporeeId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models = await remoteDataSource.getCamporeeMembers(camporeeId);
      return Right(models.map((m) => m.toEntity()).toList());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> removeMember(
      int camporeeId, String userId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      await remoteDataSource.removeMember(camporeeId, userId);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
