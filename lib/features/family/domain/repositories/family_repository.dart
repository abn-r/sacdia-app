import 'package:dartz/dartz.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dependent.dart';

/// Datos de alta de un menor (paso 0).
class CreateDependentInput {
  final String name;
  final String paternalLastName;
  final String? maternalLastName;

  /// `YYYY-MM-DD`.
  final String birthday;
  final String relationshipTypeId;

  /// El tutor declara bajo protesta ser el tutor legal. El servidor exige `true`.
  final bool swornDeclaration;
  final String acceptedTermsVersion;
  final String acceptedPrivacyVersion;

  const CreateDependentInput({
    required this.name,
    required this.paternalLastName,
    required this.birthday,
    required this.relationshipTypeId,
    required this.swornDeclaration,
    required this.acceptedTermsVersion,
    required this.acceptedPrivacyVersion,
    this.maternalLastName,
  });
}

/// Contrato de los endpoints `/guardianships` del tutor.
///
/// Todos se piden SIN `X-Acting-For`: el tutor gestiona la familia desde su
/// propio perfil. Los fallos conservan [Failure.errorCode] para que la UI
/// distinga `GUARDIANSHIP_*`; el cliente nunca depende de `details`.
abstract class FamilyRepository {
  Future<Either<Failure, FamilyOverview>> listDependents();

  Future<Either<Failure, DependentDetail>> getDependent(String dependentId);

  Future<Either<Failure, DependentSummary>> createDependent(
    CreateDependentInput input,
  );

  Future<Either<Failure, IssuedLinkCode>> issueLinkCode(String dependentId);

  Future<Either<Failure, DependentSummary>> redeemLinkCode({
    required String code,
    required String relationshipTypeId,
    required bool swornDeclaration,
  });

  Future<Either<Failure, RevokeResult>> revoke({
    required String guardianshipId,
    required bool removedByPrimary,
  });

  Future<Either<Failure, List<DeletionImpactEntry>>> deletionImpact();

  /// Sube la ficha de consentimiento firmada del menor (foto o PDF).
  ///
  /// Sin `X-Acting-For`. El tutor NO puede dejar el consentimiento verificado:
  /// eso lo hace el director (FP-78).
  Future<Either<Failure, ConsentEvidenceReceipt>> uploadConsentEvidence({
    required String dependentId,
    required ConsentEvidenceLocalFile file,
  });

  /// Ficha vigente con URL firmada (15 min). 404 `GUARDIANSHIP_EVIDENCE_NOT_FOUND`
  /// si todavía no hay.
  Future<Either<Failure, ConsentEvidenceAccess>> getConsentEvidence(
    String dependentId,
  );
}
