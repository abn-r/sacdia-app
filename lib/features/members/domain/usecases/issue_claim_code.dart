import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/claim_code.dart';
import '../repositories/members_repository.dart';

class IssueClaimCodeParams extends Equatable {
  final int clubSectionId;
  final String dependentUserId;

  const IssueClaimCodeParams({
    required this.clubSectionId,
    required this.dependentUserId,
  });

  @override
  List<Object?> get props => [clubSectionId, dependentUserId];
}

/// Variante de `issue_link_code` para un menor bajo custodia del club: el
/// director genera el código de 7 días que la familia canjea para reclamarlo.
class IssueClaimCode implements UseCase<IssuedClaimCode, IssueClaimCodeParams> {
  final MembersRepository repository;

  IssueClaimCode(this.repository);

  @override
  Future<Either<Failure, IssuedClaimCode>> call(IssueClaimCodeParams params) =>
      repository.issueClaimCode(
        clubSectionId: params.clubSectionId,
        dependentUserId: params.dependentUserId,
      );
}
