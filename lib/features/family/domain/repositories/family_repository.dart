import 'package:dartz/dartz.dart';

import '../../../../core/consent/consent_evidence.dart';
import '../../../../core/errors/failures.dart';
import '../entities/dependent.dart';
import '../entities/dependent_progress_summary.dart';
import '../entities/supervised_login.dart';

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

  /// Sube la ficha firmada ACTUANDO por el menor (paso 3 del post-registro),
  /// con `X-Acting-For`. Reemplaza el rodeo de la Fase 2 (subir desde el perfil
  /// propio del tutor). El tutor sigue sin poder verificar: eso lo hace el
  /// director.
  Future<Either<Failure, ConsentEvidenceReceipt>>
      uploadConsentEvidenceWhileActing({
    required String dependentUserId,
    required ConsentEvidenceLocalFile file,
  });

  /// `GET .../dependents/:id/supervised-login`: elegibilidad y estado del acceso
  /// propio. Solo un tutor verificado (403/404 en otro caso).
  Future<Either<Failure, SupervisedLoginStatus>> getSupervisedLogin(
    String dependentId,
  );

  /// `POST .../dependents/:id/supervised-login`. La contraseña la fija el tutor
  /// y NUNCA se devuelve ni se registra. [email] solo con el método `email`.
  Future<Either<Failure, EnabledSupervisedLogin>> enableSupervisedLogin({
    required String dependentId,
    required SupervisedLoginMethod method,
    required String password,
    String? email,
  });

  /// `POST .../supervised-login/disable`: cierra todas sus sesiones al instante.
  Future<Either<Failure, SupervisedLoginInfo>> disableSupervisedLogin({
    required String dependentId,
    String? reason,
  });

  /// `POST .../supervised-login/reactivate`. Un acceso por usuario exige una
  /// contraseña NUEVA fijada por el tutor ([password]); el de correo no.
  Future<Either<Failure, SupervisedLoginInfo>> reactivateSupervisedLogin({
    required String dependentId,
    String? password,
  });

  /// `POST .../supervised-login/password`: usuario → el tutor fija una
  /// contraseña nueva ([password]); correo → se cierran sesiones y el menor
  /// recibe el correo estándar de restablecimiento (sin contraseña).
  Future<Either<Failure, PasswordResetResult>> resetSupervisedPassword({
    required String dependentId,
    String? password,
  });

  /// `GET .../dependents/:id/summary`: progreso y asistencia (sin salud).
  Future<Either<Failure, DependentProgressSummary>> getProgressSummary(
    String dependentId,
  );

  /// Ficha vigente con URL firmada (15 min). 404 `GUARDIANSHIP_EVIDENCE_NOT_FOUND`
  /// si todavía no hay.
  Future<Either<Failure, ConsentEvidenceAccess>> getConsentEvidence(
    String dependentId,
  );
}
