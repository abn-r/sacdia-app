import 'package:dartz/dartz.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/usecases/cancellation_token.dart';
import '../../../../core/network/cancel_token_adapter.dart';
import '../../domain/entities/certification.dart';
import '../../domain/entities/certification_detail.dart';
import '../../domain/entities/certification_evidence.dart';
import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_requirement_component.dart';
import '../../domain/entities/user_certification.dart';
import '../../domain/entities/certification_progress.dart';
import '../../domain/repositories/certifications_repository.dart';
import '../datasources/certifications_remote_data_source.dart';

/// Implementación del repositorio de certificaciones.
class CertificationsRepositoryImpl implements CertificationsRepository {
  final CertificationsRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  CertificationsRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Left<Failure, T> _serverFailure<T>(ServerException e) =>
      Left(ServerFailure(message: e.message, code: e.code));

  Left<Failure, T> _authFailure<T>(AuthException e) =>
      Left(AuthFailure(message: e.message, code: e.code));

  Left<Failure, T> _unexpectedFailure<T>(Object e) =>
      Left(UnexpectedFailure(message: e.toString()));

  // ── Métodos ───────────────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<Certification>>> getCertifications({
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getCertifications(
        cancelToken: cancelToken.asDioCancelToken(),
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
  Future<Either<Failure, CertificationDetail>> getCertificationDetail(
    int certificationId, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getCertificationDetail(
        certificationId,
        cancelToken: cancelToken.asDioCancelToken(),
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
  Future<Either<Failure, List<UserCertification>>> getUserCertifications(
    String userId, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final models = await remoteDataSource.getUserCertifications(
        userId,
        cancelToken: cancelToken.asDioCancelToken(),
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
  Future<Either<Failure, CertificationProgress>> getCertificationProgress(
    String userId,
    int certificationId, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getCertificationProgress(
        userId,
        certificationId,
        cancelToken: cancelToken.asDioCancelToken(),
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
  Future<Either<Failure, void>> enrollCertification(
      String userId, int certificationId) async {
    try {
      await remoteDataSource.enrollCertification(userId, certificationId);
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
  Future<Either<Failure, Map<String, dynamic>>> updateSectionProgress(
    String userId,
    int certificationId,
    int moduleId,
    int sectionId,
    bool completed,
  ) async {
    try {
      final result = await remoteDataSource.updateSectionProgress(
        userId,
        certificationId,
        moduleId,
        sectionId,
        completed,
      );
      return Right(result);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  @override
  Future<Either<Failure, void>> unenrollCertification(
      String userId, int certificationId) async {
    try {
      await remoteDataSource.unenrollCertification(userId, certificationId);
      return const Right(null);
    } on ServerException catch (e) {
      return _serverFailure(e);
    } on AuthException catch (e) {
      return _authFailure(e);
    } catch (e) {
      return _unexpectedFailure(e);
    }
  }

  // ── Ejecución de requisitos (Fase 5) ────────────────────────────────────

  @override
  Future<Either<Failure, CertificationRequirement>> getRequirement(
    String userId,
    int certificationId,
    int sectionId, {
    RequestCancelToken? cancelToken,
  }) async {
    try {
      final model = await remoteDataSource.getRequirement(
        userId,
        certificationId,
        sectionId,
        cancelToken: cancelToken.asDioCancelToken(),
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
  Future<Either<Failure, CertificationRequirement>> saveRequirementDraft(
    String userId,
    int certificationId,
    int sectionId,
    List<CertificationComponentDraftInput> responses,
  ) async {
    try {
      final model = await remoteDataSource.saveDraft(
        userId,
        certificationId,
        sectionId,
        responses.map((r) => r.toJson()).toList(),
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
  Future<Either<Failure, CertificationRequirementSubmitResult>>
      submitRequirement(
    String userId,
    int certificationId,
    int sectionId, {
    required int lockVersion,
  }) async {
    try {
      final model = await remoteDataSource.submitRequirement(
        userId,
        certificationId,
        sectionId,
        lockVersion: lockVersion,
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
  Future<Either<Failure, CertificationEvidenceUploadTicket>>
      presignRequirementEvidence(
    String userId,
    int certificationId,
    int sectionId, {
    required int componentId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    try {
      final model = await remoteDataSource.presignEvidence(
        userId,
        certificationId,
        sectionId,
        componentId: componentId,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
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
  Future<Either<Failure, CertificationEvidence>> confirmRequirementEvidence(
    String userId,
    int certificationId,
    int sectionId, {
    required int evidenceId,
    String? checksumSha256,
  }) async {
    try {
      final model = await remoteDataSource.confirmEvidence(
        userId,
        certificationId,
        sectionId,
        evidenceId: evidenceId,
        checksumSha256: checksumSha256,
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
  Future<Either<Failure, void>> deleteRequirementEvidence(
    String userId,
    int certificationId,
    int evidenceId,
  ) async {
    try {
      await remoteDataSource.deleteEvidence(
        userId,
        certificationId,
        evidenceId,
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
  Future<Either<Failure, CertificationCloseoutUploadTicket>>
      presignCloseoutEvidence(
    String userId,
    int certificationId, {
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    try {
      final model = await remoteDataSource.presignCloseoutEvidence(
        userId,
        certificationId,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: fileSize,
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
  Future<Either<Failure, CertificationCloseoutEvidence>>
      confirmCloseoutEvidence(
    String userId,
    int certificationId, {
    required int closeoutEvidenceId,
    String? checksumSha256,
  }) async {
    try {
      final model = await remoteDataSource.confirmCloseoutEvidence(
        userId,
        certificationId,
        closeoutEvidenceId: closeoutEvidenceId,
        checksumSha256: checksumSha256,
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
  Future<Either<Failure, CertificationSubmitFinalResult>> submitFinal(
    String userId,
    int certificationId,
  ) async {
    try {
      final model = await remoteDataSource.submitFinal(
        userId,
        certificationId,
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
  Future<Either<Failure, void>> uploadEvidenceFile({
    required String uploadUrl,
    required String filePath,
    required String mimeType,
    Map<String, String> headers = const {},
    void Function(double progress)? onProgress,
  }) async {
    try {
      await remoteDataSource.uploadEvidenceFile(
        uploadUrl: uploadUrl,
        filePath: filePath,
        mimeType: mimeType,
        headers: headers,
        onProgress: onProgress,
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
}
