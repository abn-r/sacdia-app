import 'package:dartz/dartz.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/members_repository.dart';

/// `GET /club-sections/:id/membership-requests/:assignmentId/consent-evidence`.
class GetConsentEvidence implements UseCase<ConsentEvidenceAccess, String> {
  final MembersRepository repository;

  GetConsentEvidence(this.repository);

  @override
  Future<Either<Failure, ConsentEvidenceAccess>> call(String assignmentId) =>
      repository.getConsentEvidence(assignmentId);
}
