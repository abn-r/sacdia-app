import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/certifications/data/datasources/certifications_remote_data_source.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_detail_model.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_evidence_model.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_model.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_progress_model.dart';
import 'package:sacdia_app/features/certifications/data/models/certification_requirement_model.dart';
import 'package:sacdia_app/features/certifications/data/models/user_certification_model.dart';
import 'package:sacdia_app/features/certifications/data/repositories/certifications_repository_impl.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_requirement_component.dart';

class _NetworkInfo implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

/// Fake remoto que solo implementa lo necesario para Fase 5 (ejecución de
/// requisitos + cierre); el resto del contrato lanza [UnimplementedError]
/// deliberadamente para detectar usos inesperados en estos tests.
class _RemoteDataSource implements CertificationsRemoteDataSource {
  Object? error;
  List<Map<String, dynamic>>? lastSavedResponses;
  int? lastSubmittedLockVersion;
  int? lastDeletedEvidenceId;

  final CertificationRequirementModel requirementResponse;
  final CertificationRequirementSubmitResultModel submitResponse;
  final CertificationEvidenceUploadTicketModel evidenceTicketResponse;
  final CertificationEvidenceModel evidenceResponse;
  final CertificationCloseoutUploadTicketModel closeoutTicketResponse;
  final CertificationCloseoutEvidenceModel closeoutEvidenceResponse;
  final CertificationSubmitFinalResultModel submitFinalResponse;

  _RemoteDataSource({
    required this.requirementResponse,
    required this.submitResponse,
    required this.evidenceTicketResponse,
    required this.evidenceResponse,
    required this.closeoutTicketResponse,
    required this.closeoutEvidenceResponse,
    required this.submitFinalResponse,
  });

  void _throwIfNeeded() {
    if (error != null) throw error!;
  }

  @override
  Future<CertificationRequirementModel> getRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    CancelToken? cancelToken,
  }) async {
    _throwIfNeeded();
    return requirementResponse;
  }

  @override
  Future<CertificationRequirementModel> saveDraft(
    String userId,
    int enrollmentId,
    int requirementId,
    List<Map<String, dynamic>> responses,
  ) async {
    _throwIfNeeded();
    lastSavedResponses = responses;
    return requirementResponse;
  }

  @override
  Future<CertificationRequirementSubmitResultModel> submitRequirement(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int lockVersion,
  }) async {
    _throwIfNeeded();
    lastSubmittedLockVersion = lockVersion;
    return submitResponse;
  }

  @override
  Future<CertificationEvidenceUploadTicketModel> presignEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int componentId,
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    _throwIfNeeded();
    return evidenceTicketResponse;
  }

  @override
  Future<CertificationEvidenceModel> confirmEvidence(
    String userId,
    int enrollmentId,
    int requirementId, {
    required int evidenceId,
    String? checksumSha256,
  }) async {
    _throwIfNeeded();
    return evidenceResponse;
  }

  @override
  Future<void> deleteEvidence(
      String userId, int enrollmentId, int evidenceId) async {
    _throwIfNeeded();
    lastDeletedEvidenceId = evidenceId;
  }

  @override
  Future<CertificationCloseoutUploadTicketModel> presignCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required String fileName,
    required String mimeType,
    required int fileSize,
  }) async {
    _throwIfNeeded();
    return closeoutTicketResponse;
  }

  @override
  Future<CertificationCloseoutEvidenceModel> confirmCloseoutEvidence(
    String userId,
    int enrollmentId, {
    required int closeoutEvidenceId,
    String? checksumSha256,
  }) async {
    _throwIfNeeded();
    return closeoutEvidenceResponse;
  }

  @override
  Future<CertificationSubmitFinalResultModel> submitFinal(
    String userId,
    int enrollmentId,
  ) async {
    _throwIfNeeded();
    return submitFinalResponse;
  }

  @override
  Future<void> uploadEvidenceFile({
    required String uploadUrl,
    required String filePath,
    required String mimeType,
    Map<String, String> headers = const {},
    void Function(double progress)? onProgress,
  }) async {
    _throwIfNeeded();
  }

  // ── Resto del contrato: no usado por estos tests ────────────────────────
  @override
  Future<List<CertificationModel>> getCertifications({
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<CertificationDetailModel> getCertificationDetail(
    int certificationId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<List<UserCertificationModel>> getUserCertifications(
    String userId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<CertificationProgressModel> getCertificationProgress(
    String userId,
    int certificationId, {
    CancelToken? cancelToken,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> enrollCertification(String userId, int certificationId) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> updateSectionProgress(
    String userId,
    int certificationId,
    int moduleId,
    int sectionId,
    bool completed,
  ) =>
      throw UnimplementedError();

  @override
  Future<void> unenrollCertification(String userId, int certificationId) =>
      throw UnimplementedError();
}

const _requirementModel = CertificationRequirementModel(
  sectionId: 10,
  moduleId: 1,
  name: 'Requisito',
  required: true,
  status: 'DRAFT',
);

void main() {
  late _RemoteDataSource remoteDataSource;
  late CertificationsRepositoryImpl repository;

  setUp(() {
    remoteDataSource = _RemoteDataSource(
      requirementResponse: _requirementModel,
      submitResponse: CertificationRequirementSubmitResultModel(
        requirement: _requirementModel,
        progressSummary: const CertificationProgressSummaryModel(
          requiredTotal: 3,
          requiredApproved: 1,
          optionalTotal: 0,
          optionalApproved: 0,
          percentComplete: 33,
          allRequiredApproved: false,
        ),
      ),
      evidenceTicketResponse: const CertificationEvidenceUploadTicketModel(
        evidenceId: 100,
        uploadUrl: 'https://r2.example/upload',
        objectKey: 'evidences/100',
        expiresIn: 900,
      ),
      evidenceResponse: const CertificationEvidenceModel(
        evidenceId: 100,
        objectKey: 'evidences/100',
        originalFilename: 'foto.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 2048,
        uploadStatus: 'CONFIRMED',
      ),
      closeoutTicketResponse: const CertificationCloseoutUploadTicketModel(
        closeoutEvidenceId: 200,
        uploadUrl: 'https://r2.example/closeout',
        objectKey: 'closeout/200',
        expiresIn: 900,
      ),
      closeoutEvidenceResponse: const CertificationCloseoutEvidenceModel(
        closeoutEvidenceId: 200,
        uploadStatus: 'CONFIRMED',
        reviewStatus: 'PENDING',
      ),
      submitFinalResponse: const CertificationSubmitFinalResultModel(
        enrollmentId: 5,
        status: 'PENDING_FINAL_REVIEW',
      ),
    );
    repository = CertificationsRepositoryImpl(
      remoteDataSource: remoteDataSource,
      networkInfo: _NetworkInfo(),
    );
  });

  group('getRequirement', () {
    test('maps a successful response to the domain entity', () async {
      final result = await repository.getRequirement('user-1', 42, 10);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (requirement) => expect(requirement.sectionId, 10),
      );
    });

    test('maps ServerException to ServerFailure', () async {
      remoteDataSource.error =
          ServerException(message: 'no encontrado', code: 404);

      final result = await repository.getRequirement('user-1', 42, 10);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect(failure.message, 'no encontrado');
        },
        (_) => fail('expected Left'),
      );
    });

    test('maps AuthException to AuthFailure', () async {
      remoteDataSource.error = AuthException(message: 'no autorizado');

      final result = await repository.getRequirement('user-1', 42, 10);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('saveRequirementDraft', () {
    test('serializes draft inputs and forwards them to the data source',
        () async {
      final result = await repository.saveRequirementDraft(
        'user-1',
        42,
        10,
        const [
          CertificationComponentDraftInput(
            componentId: 1,
            textValue: 'Mi respuesta',
          ),
        ],
      );

      expect(result.isRight(), isTrue);
      expect(remoteDataSource.lastSavedResponses, hasLength(1));
      expect(
        remoteDataSource.lastSavedResponses!.single['text_value'],
        'Mi respuesta',
      );
    });
  });

  group('submitRequirement', () {
    test('forwards the lock version and maps the submit result', () async {
      final result = await repository.submitRequirement(
        'user-1',
        42,
        10,
        lockVersion: 3,
      );

      expect(remoteDataSource.lastSubmittedLockVersion, 3);
      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (submitResult) =>
            expect(submitResult.progressSummary.percentComplete, 33),
      );
    });

    test('maps unexpected errors to UnexpectedFailure', () async {
      remoteDataSource.error = StateError('boom');

      final result = await repository.submitRequirement(
        'user-1',
        42,
        10,
        lockVersion: 3,
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<UnexpectedFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('evidence lifecycle', () {
    test('presignRequirementEvidence maps the upload ticket', () async {
      final result = await repository.presignRequirementEvidence(
        'user-1',
        42,
        10,
        componentId: 2,
        fileName: 'foto.jpg',
        mimeType: 'image/jpeg',
        fileSize: 2048,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (ticket) => expect(ticket.evidenceId, 100),
      );
    });

    test('confirmRequirementEvidence maps the confirmed evidence', () async {
      final result = await repository.confirmRequirementEvidence(
        'user-1',
        42,
        10,
        evidenceId: 100,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (evidence) => expect(evidence.uploadStatus, 'CONFIRMED'),
      );
    });

    test('deleteRequirementEvidence forwards the evidence id', () async {
      final result =
          await repository.deleteRequirementEvidence('user-1', 42, 100);

      expect(result.isRight(), isTrue);
      expect(remoteDataSource.lastDeletedEvidenceId, 100);
    });
  });

  group('closeout', () {
    test('presignCloseoutEvidence maps the upload ticket', () async {
      final result = await repository.presignCloseoutEvidence(
        'user-1',
        42,
        fileName: 'acta.pdf',
        mimeType: 'application/pdf',
        fileSize: 4096,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (ticket) => expect(ticket.closeoutEvidenceId, 200),
      );
    });

    test('confirmCloseoutEvidence maps the confirmed evidence', () async {
      final result = await repository.confirmCloseoutEvidence(
        'user-1',
        42,
        closeoutEvidenceId: 200,
      );

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (evidence) => expect(evidence.reviewStatus, 'PENDING'),
      );
    });

    test('submitFinal maps the final submit result', () async {
      final result = await repository.submitFinal('user-1', 42);

      expect(result.isRight(), isTrue);
      result.fold(
        (_) => fail('expected Right'),
        (submitResult) => expect(submitResult.status, 'PENDING_FINAL_REVIEW'),
      );
    });

    test('maps CERT_CLOSEOUT_INCOMPLETE ServerException to ServerFailure',
        () async {
      remoteDataSource.error = ServerException(
        message: 'Faltan requisitos aprobados',
        code: 422,
      );

      final result = await repository.submitFinal('user-1', 42);

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure.message, 'Faltan requisitos aprobados'),
        (_) => fail('expected Left'),
      );
    });
  });
}
