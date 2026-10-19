import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/family_repository.dart';

class UploadGuardianConsentEvidenceParams extends Equatable {
  final String dependentId;
  final ConsentEvidenceLocalFile file;

  const UploadGuardianConsentEvidenceParams({
    required this.dependentId,
    required this.file,
  });

  @override
  List<Object?> get props => [dependentId, file];
}

/// `POST /guardianships/me/dependents/:id/consent-evidence` (multipart `file`).
class UploadGuardianConsentEvidence
    implements
        UseCase<ConsentEvidenceReceipt, UploadGuardianConsentEvidenceParams> {
  final FamilyRepository repository;

  UploadGuardianConsentEvidence(this.repository);

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>> call(
    UploadGuardianConsentEvidenceParams params,
  ) =>
      repository.uploadConsentEvidence(
        dependentId: params.dependentId,
        file: params.file,
      );
}
