import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

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
  Future<Either<Failure, EvidenceFolder?>> getEvidenceFolder(
      String clubSectionId, {CancelToken? cancelToken}) async {
    try {
      final model = await remoteDataSource.getEvidenceFolder(
          clubSectionId, cancelToken: cancelToken);
      // model == null → carpeta no existe (200 + data: null). Estado válido.
      if (model == null) return const Right(null);
      return Right(model.toEntity());
    } on NotFoundException catch (e) {
      // Fallback defensivo: backend viejo que todavía devuelve 404.
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
  Future<Either<Failure, void>> submitFolder(String folderId) async {
    try {
      await remoteDataSource.submitFolder(folderId);
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
  Future<Either<Failure, void>> submitSection({
    required String folderId,
    required String sectionId,
  }) async {
    try {
      await remoteDataSource.submitSection(
        folderId: folderId,
        sectionId: sectionId,
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

  @override
  Future<Either<Failure, EvidenceFile>> uploadFile({
    required String folderId,
    required String sectionId,
    required String filePath,
    required String fileName,
    required String mimeType,
    String? notes,
    void Function(double)? onProgress,
  }) async {
    try {
      final model = await remoteDataSource.uploadFile(
        folderId: folderId,
        sectionId: sectionId,
        filePath: filePath,
        fileName: fileName,
        mimeType: mimeType,
        notes: notes,
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
  Future<Either<Failure, void>> deleteFile(
      {required String evidenceId}) async {
    try {
      await remoteDataSource.deleteFile(evidenceId: evidenceId);
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
