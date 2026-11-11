import 'package:equatable/equatable.dart';

import '../../../../core/auth/club_role_names.dart';
import 'role_requirement.dart';

export 'role_requirement.dart';

/// Filtro de `GET .../role-candidates?filter=`.
enum RoleCandidatesFilter {
  available('available'),
  withRole('with_role'),
  notEnrolled('not_enrolled'),
  all('all');

  const RoleCandidatesFilter(this.apiValue);

  final String apiValue;
}

/// Grupo al que el servidor asigna a un candidato.
enum RoleCandidateGroup {
  available,
  withRole,
  notEnrolled;

  /// Un valor desconocido cae en `notEnrolled`: sin acción (falla cerrado).
  static RoleCandidateGroup parse(Object? raw) => switch (raw?.toString()) {
        'available' => RoleCandidateGroup.available,
        'with_role' => RoleCandidateGroup.withRole,
        _ => RoleCandidateGroup.notEnrolled,
      };

  RoleCandidatesFilter get filter => switch (this) {
        RoleCandidateGroup.available => RoleCandidatesFilter.available,
        RoleCandidateGroup.withRole => RoleCandidatesFilter.withRole,
        RoleCandidateGroup.notEnrolled => RoleCandidatesFilter.notEnrolled,
      };
}

/// Estado anual de la persona en Guías Mayores.
enum GmAnnualStatus {
  active,
  pending,
  inactive,
  none;

  static GmAnnualStatus parse(Object? raw) => switch (raw?.toString()) {
        'active' => GmAnnualStatus.active,
        'pending' => GmAnnualStatus.pending,
        'inactive' => GmAnnualStatus.inactive,
        _ => GmAnnualStatus.none,
      };
}

/// Por qué se considera Guía Mayor.
enum GuideMajorBasis {
  invested,
  approved,
  activeEnrollment,
  unknown;

  static GuideMajorBasis parse(Object? raw) => switch (raw?.toString()) {
        'INVESTED' => GuideMajorBasis.invested,
        'APPROVED' => GuideMajorBasis.approved,
        'ACTIVE_ENROLLMENT' => GuideMajorBasis.activeEnrollment,
        _ => GuideMajorBasis.unknown,
      };
}

/// Códigos de `blocked_reason`.
abstract final class RoleCandidateBlockedReason {
  static const gmMembershipRequired = 'CLUB_ROLE_GM_MEMBERSHIP_REQUIRED';
  static const consentNotVerified = 'MR_CONSENT_NOT_VERIFIED';
  static const alreadyHeld = 'CLUB_ROLE_ALREADY_HELD';
  static const selfAssignment = 'CLUB_ROLE_SELF_ASSIGNMENT';
}

/// Los cinco cargos de servicio que un Guía Mayor puede ocupar en AV/CQ, en
/// orden de visualización.
const List<String> kBoardServiceRoles = [
  ClubRoleNames.deputyDirector,
  ClubRoleNames.secretary,
  ClubRoleNames.treasurer,
  ClubRoleNames.secretaryTreasurer,
  ClubRoleNames.counselor,
];

class RoleCandidateGuideMajor extends Equatable {
  const RoleCandidateGuideMajor({
    this.basis = GuideMajorBasis.unknown,
    this.investitureYear,
    this.advanced = false,
    this.instructor = false,
  });

  final GuideMajorBasis basis;

  /// Año de investidura tal como lo envía el servidor (`"2019"`), o `null`.
  final String? investitureYear;
  final bool advanced;
  final bool instructor;

  @override
  List<Object?> get props => [basis, investitureYear, advanced, instructor];
}

class RoleCandidateCurrentRole extends Equatable {
  const RoleCandidateCurrentRole({
    required this.sectionId,
    this.clubTypeId,
    this.clubTypeName,
    required this.role,
  });

  final int sectionId;
  final int? clubTypeId;
  final String? clubTypeName;
  final String role;

  @override
  List<Object?> get props => [sectionId, clubTypeId, clubTypeName, role];
}

class RoleCandidateConsent extends Equatable {
  const RoleCandidateConsent({required this.required, required this.verified});

  final bool required;
  final bool verified;

  @override
  List<Object?> get props => [required, verified];
}

/// Una persona del club de Guías Mayores que puede recibir un cargo.
class RoleCandidate extends Equatable {
  const RoleCandidate({
    required this.userId,
    required this.name,
    this.photoUrl,
    this.age,
    this.gender,
    required this.group,
    this.gmAnnualStatus = GmAnnualStatus.none,
    this.guideMajor,
    this.currentRoles = const [],
    this.serviceYears,
    this.consent,
    this.allowedRoles = const [],
    this.blockedReason,
    this.requirements = const [],
  });

  final String userId;
  final String name;
  final String? photoUrl;
  final int? age;

  /// El contrato no lo publica hoy; si llega, concuerda el género del cargo.
  final String? gender;
  final RoleCandidateGroup group;
  final GmAnnualStatus gmAnnualStatus;
  final RoleCandidateGuideMajor? guideMajor;
  final List<RoleCandidateCurrentRole> currentRoles;
  final int? serviceYears;
  final RoleCandidateConsent? consent;
  final List<String> allowedRoles;
  final String? blockedReason;

  /// Per-role requirements (constancia de consejería). Empty = none.
  final List<RoleRequirement> requirements;

  /// Requirement attached to [role], if any.
  RoleRequirement? requirementFor(String role) {
    for (final r in requirements) {
      if (r.role == role) return r;
    }
    return null;
  }

  /// Some requirement is not met in WARN/BLOCK mode (“Sin constancia” chip).
  bool get hasFlaggedRequirement => requirements.any((r) => r.isFlagged);

  /// Menor cuyo consentimiento falta por verificar.
  bool get isConsentMissing =>
      consent != null && consent!.required && !consent!.verified;

  /// Cargos que ya ocupa en la sección [sectionId].
  List<RoleCandidateCurrentRole> rolesInSection(int sectionId) =>
      currentRoles.where((r) => r.sectionId == sectionId).toList();

  bool holdsRoleInSection(int sectionId) =>
      currentRoles.any((r) => r.sectionId == sectionId);

  /// Cargos que ocupa en OTRAS secciones (aviso de confirmación).
  List<RoleCandidateCurrentRole> rolesElsewhere(int sectionId) =>
      currentRoles.where((r) => r.sectionId != sectionId).toList();

  /// Solo se puede elegir a quien el servidor dejó con algún cargo permitido;
  /// además, nunca a un menor sin consentimiento ni a quien ya tiene un cargo
  /// en esta sección.
  bool isActionable(int sectionId) =>
      allowedRoles.isNotEmpty &&
      !isConsentMissing &&
      !holdsRoleInSection(sectionId) &&
      group != RoleCandidateGroup.notEnrolled;

  @override
  List<Object?> get props => [
        userId,
        name,
        photoUrl,
        age,
        gender,
        group,
        gmAnnualStatus,
        guideMajor,
        currentRoles,
        serviceYears,
        consent,
        allowedRoles,
        blockedReason,
        requirements,
      ];
}

/// Estado de un cargo de servicio en la sección.
class RoleSlot extends Equatable {
  const RoleSlot({
    required this.role,
    this.occupied = 0,
    this.max,
    this.holders = const [],
    this.blockedBy = const [],
  });

  final String role;
  final int occupied;

  /// `null`: sin tope (consejeros).
  final int? max;
  final List<String> holders;

  /// Cargos que, ocupados, impiden este.
  final List<String> blockedBy;

  bool get isUnbounded => max == null;
  bool get isFull => max != null && occupied >= max!;

  @override
  List<Object?> get props => [role, occupied, max, holders, blockedBy];
}

class RoleCandidatesSection extends Equatable {
  const RoleCandidatesSection({
    required this.id,
    this.clubTypeId,
    this.clubTypeName,
    this.yearName,
    this.hasGmSection = true,
  });

  final int id;
  final int? clubTypeId;
  final String? clubTypeName;
  final String? yearName;

  /// `false` when the club has no Guías Mayores section (empty list).
  final bool hasGmSection;

  @override
  List<Object?> get props =>
      [id, clubTypeId, clubTypeName, yearName, hasGmSection];
}

class RoleCandidatesCounts extends Equatable {
  const RoleCandidatesCounts({
    this.available = 0,
    this.withRole = 0,
    this.notEnrolled = 0,
  });

  final int available;
  final int withRole;
  final int notEnrolled;

  int of(RoleCandidatesFilter filter) => switch (filter) {
        RoleCandidatesFilter.available => available,
        RoleCandidatesFilter.withRole => withRole,
        RoleCandidatesFilter.notEnrolled => notEnrolled,
        RoleCandidatesFilter.all => available + withRole + notEnrolled,
      };

  @override
  List<Object?> get props => [available, withRole, notEnrolled];
}

/// Una página de `GET .../role-candidates`.
class RoleCandidatesPage extends Equatable {
  const RoleCandidatesPage({
    this.section,
    this.slots = const [],
    this.items = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.counts = const RoleCandidatesCounts(),
  });

  final RoleCandidatesSection? section;
  final List<RoleSlot> slots;
  final List<RoleCandidate> items;
  final int page;
  final int limit;
  final int total;
  final RoleCandidatesCounts counts;

  RoleSlot? slotFor(String role) {
    for (final slot in slots) {
      if (slot.role == role) return slot;
    }
    return null;
  }

  @override
  List<Object?> get props =>
      [section, slots, items, page, limit, total, counts];
}

class RoleHistoryEntry extends Equatable {
  const RoleHistoryEntry(
      {this.yearName, this.clubTypeName, required this.role});

  final String? yearName;
  final String? clubTypeName;
  final String role;

  @override
  List<Object?> get props => [yearName, clubTypeName, role];
}

class RoleCandidateCertification extends Equatable {
  const RoleCandidateCertification({
    required this.name,
    this.status,
    this.certifiedAt,
  });

  final String name;
  final String? status;
  final DateTime? certifiedAt;

  @override
  List<Object?> get props => [name, status, certifiedAt];
}

class RoleCandidateInsurance extends Equatable {
  const RoleCandidateInsurance({required this.active, this.expiresAt});

  final bool active;
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [active, expiresAt];
}

/// `GET .../role-candidates/:userId`: el candidato más su detalle.
class RoleCandidateDetail extends Equatable {
  const RoleCandidateDetail({
    required this.candidate,
    this.roleHistory = const [],
    this.certifications = const [],
    this.insurance,
    this.honorsCount = 0,
    this.credentials = const [],
  });

  final RoleCandidate candidate;
  final List<RoleHistoryEntry> roleHistory;
  final List<RoleCandidateCertification> certifications;
  final RoleCandidateInsurance? insurance;
  final int honorsCount;
  final List<RoleCandidateCredential> credentials;

  /// Best counselor-training credential: approved, then in review, then the
  /// rest. `null` when the person has none.
  RoleCandidateCredential? get counselorCredential {
    RoleCandidateCredential? best;
    for (final c in credentials) {
      if (c.type != RoleRequirement.counselorTraining) continue;
      if (best == null || c.status.index < best.status.index) best = c;
    }
    return best;
  }

  /// Severity (0 info, 1 warn, 2 enforced block) of the strictest requirement,
  /// or `null` when the candidate has no requirements.
  int? get requirementSeverity {
    if (candidate.requirements.isEmpty) return null;
    return candidate.requirements
        .map((r) => r.severity)
        .reduce((a, b) => a > b ? a : b);
  }

  @override
  List<Object?> get props => [
        candidate,
        roleHistory,
        certifications,
        insurance,
        honorsCount,
        credentials,
      ];
}
