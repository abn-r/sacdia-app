import 'package:dartz/dartz.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../entities/service_credential.dart';
import '../entities/service_credential_review.dart';

/// Contrato de «Mis constancias» y de la cola de revisión. Todo fallo conserva
/// el `errorCode` de negocio del servidor (`SERVICE_CREDENTIAL_*`).
abstract class ServiceCredentialsRepository {
  Future<Either<Failure, List<ServiceCredential>>> getMine();

  /// Registra la constancia, sube el archivo a la URL firmada y la confirma.
  /// [onPhase] y [onProgress] (0..1 de la subida) pintan el avance.
  Future<Either<Failure, ServiceCredential>> submit({
    required ServiceCredentialDraft draft,
    required ConsentEvidenceLocalFile file,
    void Function(ServiceCredentialSubmitPhase phase)? onPhase,
    void Function(double progress)? onProgress,
  });

  Future<Either<Failure, Unit>> withdraw(String id);

  Future<Either<Failure, ReviewPage>> getReviewQueue({
    required ReviewStatusFilter status,
    String search = '',
    int page = 1,
    int limit = 20,
  });

  Future<Either<Failure, ReviewDetail>> getReviewDetail(String id);

  Future<Either<Failure, Unit>> approve(String id, {DateTime? expiresAt});

  Future<Either<Failure, Unit>> reject(String id, {required String reason});
}
