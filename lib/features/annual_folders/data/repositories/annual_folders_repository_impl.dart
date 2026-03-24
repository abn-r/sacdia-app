import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/annual_folder.dart';
import '../../domain/repositories/annual_folders_repository.dart';
import '../datasources/annual_folders_remote_data_source.dart';

/// Implementación del repositorio de carpetas anuales
class AnnualFoldersRepositoryImpl implements AnnualFoldersRepository {
  final AnnualFoldersRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  AnnualFoldersRepositoryImpl({
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
  Future<Either<Failure, AnnualFolder>> getFolderByEnrollment(
      int enrollmentId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.getFolderByEnrollment(enrollmentId);
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
  Future<Either<Failure, FolderEvidence>> uploadEvidence(
    int folderId, {
    required int sectionId,
    required String fileUrl,
    required String fileName,
    String? notes,
  }) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.uploadEvidence(
        folderId,
        sectionId: sectionId,
        fileUrl: fileUrl,
        fileName: fileName,
        notes: notes,
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
  Future<Either<Failure, void>> deleteEvidence(int evidenceId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      await remoteDataSource.deleteEvidence(evidenceId);
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
  Future<Either<Failure, AnnualFolder>> submitFolder(int folderId) async {
    if (!await _isConnected) return _networkFailure();
    try {
      final model = await remoteDataSource.submitFolder(folderId);
      return Right(model.toEntity());
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }
}
