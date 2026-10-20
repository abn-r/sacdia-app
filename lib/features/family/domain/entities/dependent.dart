import 'package:equatable/equatable.dart';

import 'supervised_login.dart';

/// Estado del consentimiento de una tutoría que el cliente puede ver.
///
/// El servidor nunca devuelve `revoked` en estos endpoints (una tutoría
/// revocada deja de listarse), así que un valor desconocido se trata como
/// `pending`, que es el lado seguro.
enum GuardianConsentStatus {
  pending,
  verified;

  static GuardianConsentStatus parse(Object? raw) =>
      raw == 'verified' ? verified : pending;
}

/// Qué pasa con un menor cuando su tutor sale o borra la cuenta.
enum DependentOutcome {
  /// Queda otro tutor activo.
  otherGuardian,

  /// El club se queda con la custodia.
  clubCustody,

  /// Sin tutor ni club: se congela y se borra a los 90 días.
  frozen,

  /// Menor CON cuenta propia (adolescente) que se queda sin tutor: no se
  /// congela, vuelve al modo restringido y tiene 90 días para vincular a otro
  /// tutor (FP3-37).
  pendingGuardian;

  static DependentOutcome parse(Object? raw) => switch (raw) {
        'other_guardian' => otherGuardian,
        'club_custody' => clubCustody,
        'pending_guardian' => pendingGuardian,
        _ => frozen,
      };
}

/// Tipo de parentesco (`relationship_types`).
class RelationshipRef extends Equatable {
  final String id;
  final String name;

  const RelationshipRef({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}

/// La tutoría del usuario actual sobre un menor.
class DependentGuardianship extends Equatable {
  final String guardianshipId;
  final bool isPrimary;
  final RelationshipRef? relationshipType;
  final GuardianConsentStatus consentStatus;
  final DateTime? verifiedAt;
  final bool evidenceUploaded;

  const DependentGuardianship({
    required this.guardianshipId,
    required this.isPrimary,
    required this.consentStatus,
    required this.evidenceUploaded,
    this.relationshipType,
    this.verifiedAt,
  });

  bool get isVerified => consentStatus == GuardianConsentStatus.verified;

  @override
  List<Object?> get props => [
        guardianshipId,
        isPrimary,
        relationshipType,
        consentStatus,
        verifiedAt,
        evidenceUploaded,
      ];
}

/// Solicitud o membresía del menor en un club.
class DependentClubMembership extends Equatable {
  final String assignmentId;

  /// `pending`, `active`, `rejected`, `expired` o `cancelled`.
  final String status;
  final int? clubSectionId;
  final String? clubName;
  final String? clubTypeName;

  const DependentClubMembership({
    required this.assignmentId,
    required this.status,
    this.clubSectionId,
    this.clubName,
    this.clubTypeName,
  });

  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';

  @override
  List<Object?> get props =>
      [assignmentId, status, clubSectionId, clubName, clubTypeName];
}

/// Cómo entra el menor a la app (calculado por el servidor).
enum AccessMode {
  /// Sin cuenta: el tutor actúa por él (o, a futuro, un teléfono vinculado).
  guardianManaged,

  /// Con acceso propio (usuario o correo + contraseña): el tutor lo supervisa.
  supervisedLogin;

  /// Un valor ausente o desconocido es el modo más restrictivo del lado del
  /// tutor: sin acceso propio (el tutor puede actuar).
  static AccessMode parse(Object? raw) =>
      raw == 'supervised_login' ? supervisedLogin : guardianManaged;
}

/// Menor sin cuenta, tal como lo ve su tutor (`DependentSummary`).
class DependentSummary extends Equatable {
  final String userId;
  final String? name;
  final String? paternalLastName;
  final String? maternalLastName;
  final DateTime? birthday;
  final int? age;
  final String? userImage;
  final bool postRegisterComplete;

  /// Congelado: sin tutor ni club, a la espera del borrado a los 90 días. No
  /// se puede actuar por él.
  final bool frozen;
  final DependentGuardianship guardianship;
  final DependentClubMembership? clubMembership;

  /// `guardian_managed` o `supervised_login` (FP3-33).
  final AccessMode accessMode;

  /// Acceso propio del menor (nulo si nunca se activó).
  final SupervisedLoginInfo? supervisedLogin;

  /// Teléfonos vinculados (hasta la fase 3b es siempre 0).
  final int linkedDevicesCount;

  /// Ya cumplió la edad mínima de acceso propio y todavía no lo tiene.
  final bool ageMilestoneReached;

  const DependentSummary({
    required this.userId,
    required this.guardianship,
    this.name,
    this.paternalLastName,
    this.maternalLastName,
    this.birthday,
    this.age,
    this.userImage,
    this.postRegisterComplete = false,
    this.frozen = false,
    this.clubMembership,
    this.accessMode = AccessMode.guardianManaged,
    this.supervisedLogin,
    this.linkedDevicesCount = 0,
    this.ageMilestoneReached = false,
  });

  /// El menor entra con su propio acceso activo (el tutor ya no actúa por él).
  bool get hasActiveOwnLogin =>
      accessMode == AccessMode.supervisedLogin &&
      !(supervisedLogin?.isDisabled ?? false);

  /// Nombre de pila para el banner y el selector. Nunca vacío.
  String get firstName {
    final value = name?.trim();
    return (value == null || value.isEmpty) ? '—' : value;
  }

  String get fullName {
    final parts = [name, paternalLastName, maternalLastName]
        .whereType<String>()
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    final joined = parts.join(' ');
    return joined.isEmpty ? '—' : joined;
  }

  /// Se puede ver como este menor desde el selector de perfiles.
  ///
  /// Con acceso propio activo el servidor ya no deja actuar por él (403
  /// `ACTING_FOR_FORBIDDEN`): no aparece en el selector ni en los push.
  bool get canActAs => !frozen && !hasActiveOwnLogin;

  @override
  List<Object?> get props => [
        userId,
        name,
        paternalLastName,
        maternalLastName,
        birthday,
        age,
        userImage,
        postRegisterComplete,
        frozen,
        guardianship,
        clubMembership,
        accessMode,
        supervisedLogin,
        linkedDevicesCount,
        ageMilestoneReached,
      ];
}

/// Un tutor de un menor (`DependentDetail.guardians`).
class DependentGuardian extends Equatable {
  final String guardianshipId;

  /// Nulo para custodia de club o tutor externo.
  final String? userId;
  final String displayName;
  final String? relationshipTypeName;
  final bool isPrimary;
  final bool isCustodian;
  final GuardianConsentStatus consentStatus;
  final bool isMe;

  const DependentGuardian({
    required this.guardianshipId,
    required this.displayName,
    required this.isPrimary,
    required this.isCustodian,
    required this.consentStatus,
    required this.isMe,
    this.userId,
    this.relationshipTypeName,
  });

  @override
  List<Object?> get props => [
        guardianshipId,
        userId,
        displayName,
        relationshipTypeName,
        isPrimary,
        isCustodian,
        consentStatus,
        isMe,
      ];
}

/// `DependentSummary` más la lista de tutores.
class DependentDetail extends Equatable {
  final DependentSummary summary;
  final List<DependentGuardian> guardians;

  const DependentDetail({required this.summary, required this.guardians});

  /// Tutores humanos activos que no soy yo (a quienes puedo quitar siendo
  /// primario).
  Iterable<DependentGuardian> get otherGuardians =>
      guardians.where((g) => !g.isMe && !g.isCustodian && g.userId != null);

  @override
  List<Object?> get props => [summary, guardians];
}

/// Lista de menores del tutor más su límite.
class FamilyOverview extends Equatable {
  final List<DependentSummary> dependents;
  final int maxDependents;

  const FamilyOverview({required this.dependents, required this.maxDependents});

  /// Aún se puede añadir otro menor. El servidor es la fuente de verdad
  /// (409 `GUARDIANSHIP_DEPENDENT_LIMIT_REACHED`); esto solo adelanta el botón.
  bool get canAddMore => dependents.length < maxDependents;

  /// Menores por los que se puede actuar (no congelados).
  List<DependentSummary> get actable =>
      dependents.where((d) => d.canActAs).toList(growable: false);

  @override
  List<Object?> get props => [dependents, maxDependents];
}

/// Qué le pasaría a un menor si el tutor borra su cuenta.
class DeletionImpactEntry extends Equatable {
  final String userId;
  final String displayName;
  final DependentOutcome outcome;

  const DeletionImpactEntry({
    required this.userId,
    required this.displayName,
    required this.outcome,
  });

  @override
  List<Object?> get props => [userId, displayName, outcome];
}

/// Código para invitar a un segundo tutor (`XXXX-XXXX`).
class IssuedLinkCode extends Equatable {
  final String code;
  final DateTime expiresAt;

  const IssuedLinkCode({required this.code, required this.expiresAt});

  @override
  List<Object?> get props => [code, expiresAt];
}

/// Resultado de salir de una tutoría.
class RevokeResult extends Equatable {
  final String guardianshipId;
  final DependentOutcome outcome;

  const RevokeResult({required this.guardianshipId, required this.outcome});

  @override
  List<Object?> get props => [guardianshipId, outcome];
}
