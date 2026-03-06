import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/evidence_file.dart';
import '../../domain/entities/evidence_folder.dart';
import '../../domain/repositories/evidence_folder_repository.dart';
import '../datasources/evidence_folder_remote_data_source.dart';

/// Implementación concreta del [EvidenceFolderRepository].
///
/// Delega llamadas de red al [EvidenceFolderRemoteDataSource] y convierte
/// excepciones en valores de tipo [Either<Failure, T>].
class EvidenceFolderRepositoryImpl implements EvidenceFolderRepository {
  final EvidenceFolderRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  EvidenceFolderRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, EvidenceFolder>> getEvidenceFolder(
      String clubInstanceId) async {
    if (!await networkInfo.isConnected) {
      return const Left(
          NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model =
          await remoteDataSource.getEvidenceFolder(clubInstanceId);
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
  Future<Either<Failure, void>> submitSection(
      String clubInstanceId, String sectionId) async {
    if (!await networkInfo.isConnected) {
      return const Left(
          NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      await remoteDataSource.submitSection(clubInstanceId, sectionId);
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
  Future<Either<Failure, EvidenceFile>> uploadFile({
    required String clubInstanceId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(
          NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      final model = await remoteDataSource.uploadFile(
        clubInstanceId: clubInstanceId,
        sectionId: sectionId,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
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
  Future<Either<Failure, void>> deleteFile({
    required String clubInstanceId,
    required String sectionId,
    required String fileId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(
          NetworkFailure(message: 'No hay conexión a internet'));
    }
    try {
      await remoteDataSource.deleteFile(
        clubInstanceId: clubInstanceId,
        sectionId: sectionId,
        fileId: fileId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnexpectedFailure(message: e.toString()));
    }
  }
}
