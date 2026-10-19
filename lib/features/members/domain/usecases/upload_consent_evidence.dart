import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/members_repository.dart';

class UploadConsentEvidenceParams extends Equatable {
  final String assignmentId;
  final ConsentEvidenceLocalFile file;

  const UploadConsentEvidenceParams({
    required this.assignmentId,
    required this.file,
  });

  @override
  List<Object?> get props => [assignmentId, file];
}

/// `POST /club-sections/:id/membership-requests/:assignmentId/consent-evidence`.
class UploadConsentEvidence
    implements UseCase<ConsentEvidenceReceipt, UploadConsentEvidenceParams> {
  final MembersRepository repository;

  UploadConsentEvidence(this.repository);

  @override
  Future<Either<Failure, ConsentEvidenceReceipt>> call(
    UploadConsentEvidenceParams params,
  ) =>
      repository.uploadConsentEvidence(
        assignmentId: params.assignmentId,
        file: params.file,
      );
}
