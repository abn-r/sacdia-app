import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/dependent.dart';
import '../repositories/family_repository.dart';

class RedeemLinkCodeParams extends Equatable {
  /// Tal como lo escribió la persona: el servidor normaliza mayúsculas, guion y
  /// espacios, así que no se toca.
  final String code;
  final String relationshipTypeId;
  final bool swornDeclaration;

  const RedeemLinkCodeParams({
    required this.code,
    required this.relationshipTypeId,
    required this.swornDeclaration,
  });

  @override
  List<Object?> get props => [code, relationshipTypeId, swornDeclaration];
}

/// `POST /guardianships/link-codes/redeem`.
class RedeemLinkCode
    implements UseCase<DependentSummary, RedeemLinkCodeParams> {
  final FamilyRepository repository;

  RedeemLinkCode(this.repository);

  @override
  Future<Either<Failure, DependentSummary>> call(
    RedeemLinkCodeParams params,
  ) =>
      repository.redeemLinkCode(
        code: params.code,
        relationshipTypeId: params.relationshipTypeId,
        swornDeclaration: params.swornDeclaration,
      );
}
