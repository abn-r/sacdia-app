import 'package:dartz/dartz.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/family_repository.dart';

/// `GET /guardianships/me/dependents/:id/consent-evidence` (URL firmada, 15 min).
class GetGuardianConsentEvidence
    implements UseCase<ConsentEvidenceAccess, String> {
  final FamilyRepository repository;

  GetGuardianConsentEvidence(this.repository);

  @override
  Future<Either<Failure, ConsentEvidenceAccess>> call(String dependentId) =>
      repository.getConsentEvidence(dependentId);
}
