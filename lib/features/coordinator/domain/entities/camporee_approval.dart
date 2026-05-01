import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

// ── Camporee type ─────────────────────────────────────────────────────────────

/// Scope del camporee: local (campo local) o union (campo unión).
enum CamporeeScope {
  local,
  union;

  String get displayLabel {
    switch (this) {
      case CamporeeScope.local:
        return tr('coordinator.camporee_scope.local');
      case CamporeeScope.union:
        return tr('coordinator.camporee_scope.union');
    }
  }
}

// ── Approval type tabs ────────────────────────────────────────────────────────

/// Tipo de inscripción pendiente: clubs, miembros o pagos.
enum CamporeeApprovalType {
  club,
  member,
  payment;

  static CamporeeApprovalType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'club':
        return CamporeeApprovalType.club;
      case 'member':
        return CamporeeApprovalType.member;
      case 'payment':
        return CamporeeApprovalType.payment;
      default:
        return CamporeeApprovalType.club;
    }
  }

  String get displayLabel {
    switch (this) {
      case CamporeeApprovalType.club:
        return tr('coordinator.approval_type.clubs');
      case CamporeeApprovalType.member:
        return tr('coordinator.approval_type.members');
      case CamporeeApprovalType.payment:
        return tr('coordinator.approval_type.payments');
    }
  }
}

/// Estado de una inscripción.
enum CamporeeApprovalStatus {
  registered,
  pendingApproval,
  approved,
  rejected,
  cancelled;

  static CamporeeApprovalStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
        return CamporeeApprovalStatus.approved;
      case 'rejected':
        return CamporeeApprovalStatus.rejected;
      case 'cancelled':
        return CamporeeApprovalStatus.cancelled;
      case 'registered':
        return CamporeeApprovalStatus.registered;
      default:
        return CamporeeApprovalStatus.pendingApproval;
    }
  }
}

// ── Camporee summary ──────────────────────────────────────────────────────────

/// Entidad de camporee para el selector de la vista de aprobaciones.
class CamporeeItem extends Equatable {
  final int id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final CamporeeScope scope;
  final bool active;

  const CamporeeItem({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.scope,
    required this.active,
  });

  @override
  List<Object?> get props => [id, name, scope];
}

// ── Pending approvals envelope ────────────────────────────────────────────────

/// Respuesta del endpoint GET /camporees/:id/pending.
/// Contiene listas de clubs, miembros y pagos con status pending_approval.
class CamporeePendingApprovals extends Equatable {
  final List<CamporeeClubEnrollment> clubs;
  final List<CamporeeMemberEnrollment> members;
  final List<CamporeePaymentEnrollment> payments;

  const CamporeePendingApprovals({
    required this.clubs,
    required this.members,
    required this.payments,
  });

  int get totalPending => clubs.length + members.length + payments.length;

  @override
  List<Object?> get props => [clubs, members, payments];
}

// ── Club enrollment ───────────────────────────────────────────────────────────

/// Inscripción de un club en un camporee con estado pending_approval.
///
/// El ID es [camporeeClubId] (int), necesario para las rutas de aprobación:
///   PATCH /camporees/:camporeeId/clubs/:camporeeClubId/approve
class CamporeeClubEnrollment extends Equatable {
  final int camporeeClubId;
  final int camporeeId;
  final int clubSectionId;
  final String? sectionName;
  final String? clubName;
  final CamporeeApprovalStatus status;
  final String? registeredByName;
  final DateTime? createdAt;
  final String? rejectionReason;

  const CamporeeClubEnrollment({
    required this.camporeeClubId,
    required this.camporeeId,
    required this.clubSectionId,
    this.sectionName,
    this.clubName,
    required this.status,
    this.registeredByName,
    this.createdAt,
    this.rejectionReason,
  });

  String get displayName => clubName ?? sectionName ?? tr('coordinator.camporee_approvals.unknown_club');

  @override
  List<Object?> get props => [camporeeClubId, camporeeId, clubSectionId, status];
}

// ── Member enrollment ─────────────────────────────────────────────────────────

/// Inscripción de un miembro en un camporee con estado pending_approval.
///
/// El ID es [camporeeMemberId] (int) — extraído del campo [camporee_member_id]
/// en la respuesta. Usado en:
///   PATCH /camporees/:camporeeId/members/:camporeeMemberId/approve
class CamporeeMemberEnrollment extends Equatable {
  final int camporeeMemberId;
  final String userId;
  final int camporeeId;
  final String? memberName;
  final String? clubName;
  final String? pictureUrl;
  final CamporeeApprovalStatus status;
  final DateTime? createdAt;
  final String? rejectionReason;

  const CamporeeMemberEnrollment({
    required this.camporeeMemberId,
    required this.userId,
    required this.camporeeId,
    this.memberName,
    this.clubName,
    this.pictureUrl,
    required this.status,
    this.createdAt,
    this.rejectionReason,
  });

  String get displayName => memberName ?? userId;

  @override
  List<Object?> get props =>
      [camporeeMemberId, userId, camporeeId, status];
}

// ── Payment enrollment ────────────────────────────────────────────────────────

/// Pago de inscripción en un camporee con estado pending_approval.
///
/// El ID es [camporeePaymentId] (String/UUID) — la ruta de aprobación NO
/// lleva camporeeId como prefijo:
///   PATCH /camporees/payments/:camporeePaymentId/approve
class CamporeePaymentEnrollment extends Equatable {
  final int paymentId;
  final String? camporeePaymentId;
  final int camporeeId;
  final String memberId;
  final String? memberName;
  final double amount;
  final String paymentType;
  final String? reference;
  final String? notes;
  final CamporeeApprovalStatus status;
  final DateTime? createdAt;
  final String? rejectionReason;

  const CamporeePaymentEnrollment({
    required this.paymentId,
    this.camporeePaymentId,
    required this.camporeeId,
    required this.memberId,
    this.memberName,
    required this.amount,
    required this.paymentType,
    this.reference,
    this.notes,
    required this.status,
    this.createdAt,
    this.rejectionReason,
  });

  /// ID to use in approval routes — camporeePaymentId if present, else paymentId string.
  String get approvalId =>
      camporeePaymentId ?? paymentId.toString();

  String get displayName => memberName ?? memberId;

  @override
  List<Object?> get props => [paymentId, camporeeId, memberId, status];
}

// ── Legacy alias kept for backward compatibility with any remaining references ─
// ignore: avoid_classes_with_only_static_members
@Deprecated('Use CamporeeClubEnrollment / CamporeeMemberEnrollment / CamporeePaymentEnrollment')
class CamporeeApproval extends Equatable {
  final String id;
  final CamporeeApprovalType type;
  final CamporeeApprovalStatus status;
  final String camporeeName;
  final String requestingClubName;
  final String? subjectName;
  final DateTime requestedAt;
  final double? amount;

  const CamporeeApproval({
    required this.id,
    required this.type,
    required this.status,
    required this.camporeeName,
    required this.requestingClubName,
    this.subjectName,
    required this.requestedAt,
    this.amount,
  });

  @override
  List<Object?> get props => [id, type, status];
}
