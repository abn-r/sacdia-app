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
      String clubSectionId) async {
    try {
      final model =
          await remoteDataSource.getEvidenceFolder(clubSectionId);
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
      String clubSectionId, String sectionId) async {
    try {
      await remoteDataSource.submitSection(clubSectionId, sectionId);
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
    required String clubSectionId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    void Function(double)? onProgress,
  }) async {
    try {
      final model = await remoteDataSource.uploadFile(
        clubSectionId: clubSectionId,
        sectionId: sectionId,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        onProgress: onProgress,
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
    required String clubSectionId,
    required String sectionId,
    required String fileId,
  }) async {
    try {
      await remoteDataSource.deleteFile(
        clubSectionId: clubSectionId,
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
