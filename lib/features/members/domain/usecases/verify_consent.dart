import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/consent_verification_result.dart';
import '../repositories/members_repository.dart';

class VerifyConsentParams extends Equatable {
  final String assignmentId;

  /// Aprobar la solicitud en la misma llamada.
  final bool approve;

  const VerifyConsentParams({required this.assignmentId, this.approve = true});

  @override
  List<Object?> get props => [assignmentId, approve];
}

/// `POST .../verify-consent` con `confirm_paper_form_reviewed: true`.
class VerifyConsent
    implements UseCase<ConsentVerificationResult, VerifyConsentParams> {
  final MembersRepository repository;

  VerifyConsent(this.repository);

  @override
  Future<Either<Failure, ConsentVerificationResult>> call(
    VerifyConsentParams params,
  ) =>
      repository.verifyConsent(
        assignmentId: params.assignmentId,
        approve: params.approve,
      );
}
