import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/investiture_pending.dart';
import '../../domain/entities/investiture_history_entry.dart';
import '../../domain/repositories/investiture_repository.dart';
import '../datasources/investiture_remote_data_source.dart';

/// Implementación del repositorio de investidura.
class InvestitureRepositoryImpl implements InvestitureRepository {
  final InvestitureRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  InvestitureRepositoryImpl({
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
  Future<Either<Failure, void>> submitForValidation({
    required int enrollmentId,
    required int clubId,
    String? comments,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      await remoteDataSource.submitForValidation(
        enrollmentId: enrollmentId,
        clubId: clubId,
        comments: comments,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> validateEnrollment({
    required int enrollmentId,
    required String action,
    String? comments,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      await remoteDataSource.validateEnrollment(
        enrollmentId: enrollmentId,
        action: action,
        comments: comments,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> markAsInvestido({
    required int enrollmentId,
    String? comments,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      await remoteDataSource.markAsInvestido(
        enrollmentId: enrollmentId,
        comments: comments,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, List<InvestiturePending>>> getPendingInvestitures({
    int? localFieldId,
    int? ecclesiasticalYearId,
    int page = 1,
    int limit = 20,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models = await remoteDataSource.getPendingInvestitures(
        localFieldId: localFieldId,
        ecclesiasticalYearId: ecclesiasticalYearId,
        page: page,
        limit: limit,
      );
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
  Future<Either<Failure, List<InvestitureHistoryEntry>>> getInvestitureHistory({
    required int enrollmentId,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final models = await remoteDataSource.getInvestitureHistory(
        enrollmentId: enrollmentId,
      );
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
