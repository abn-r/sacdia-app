import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee_approval.dart';

// ── CamporeeItemModel ─────────────────────────────────────────────────────────

/// Modelo para un camporee del endpoint GET /camporees o GET /camporees/union.
class CamporeeItemModel extends Equatable {
  final int id;
  final String name;
  final String? description;
  final DateTime startDate;
  final DateTime endDate;
  final CamporeeScope scope;
  final bool active;

  const CamporeeItemModel({
    required this.id,
    required this.name,
    this.description,
    required this.startDate,
    required this.endDate,
    required this.scope,
    required this.active,
  });

  factory CamporeeItemModel.fromJson(
    Map<String, dynamic> json, {
    CamporeeScope scope = CamporeeScope.local,
  }) {
    // Local camporee uses camporee_id / local_camporee_id, union uses union_camporee_id
    final id = (json['camporee_id'] ??
            json['local_camporee_id'] ??
            json['union_camporee_id'] ??
            json['id'] ??
            0) as int;

    return CamporeeItemModel(
      id: id,
      name: (json['name'] ?? '') as String,
      description: json['description'] as String?,
      startDate: DateTime.tryParse((json['start_date'] ?? '') as String) ??
          DateTime.now(),
      endDate: DateTime.tryParse((json['end_date'] ?? '') as String) ??
          DateTime.now(),
      scope: scope,
      active: (json['active'] ?? true) as bool,
    );
  }

  CamporeeItem toEntity() => CamporeeItem(
        id: id,
        name: name,
        description: description,
        startDate: startDate,
        endDate: endDate,
        scope: scope,
        active: active,
      );

  @override
  List<Object?> get props => [id, name, scope];
}

// ── CamporeedPendingApprovalsModel ────────────────────────────────────────────

/// Modelo para la respuesta del endpoint GET /camporees/:id/pending.
///
/// El backend devuelve: { clubs: [...], members: [...], payments: [...] }
class CamporeePendingApprovalsModel extends Equatable {
  final List<CamporeeClubEnrollmentModel> clubs;
  final List<CamporeeMemberEnrollmentModel> members;
  final List<CamporeePaymentEnrollmentModel> payments;

  const CamporeePendingApprovalsModel({
    required this.clubs,
    required this.members,
    required this.payments,
  });

  factory CamporeePendingApprovalsModel.fromJson(
    Map<String, dynamic> json, {
    required int camporeeId,
  }) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      final list = raw is List ? raw : [];
      return list
          .whereType<Map<String, dynamic>>()
          .map((e) => fromJson(e))
          .toList();
    }

    return CamporeePendingApprovalsModel(
      clubs: parseList(
        json['clubs'],
        (j) => CamporeeClubEnrollmentModel.fromJson(j, camporeeId: camporeeId),
      ),
      members: parseList(
        json['members'],
        (j) =>
            CamporeeMemberEnrollmentModel.fromJson(j, camporeeId: camporeeId),
      ),
      payments: parseList(
        json['payments'],
        (j) =>
            CamporeePaymentEnrollmentModel.fromJson(j, camporeeId: camporeeId),
      ),
    );
  }

  CamporeePendingApprovals toEntity() => CamporeePendingApprovals(
        clubs: clubs.map((m) => m.toEntity()).toList(),
        members: members.map((m) => m.toEntity()).toList(),
        payments: payments.map((m) => m.toEntity()).toList(),
      );

  @override
  List<Object?> get props => [clubs, members, payments];
}

// ── CamporeeClubEnrollmentModel ───────────────────────────────────────────────

/// Modelo para una inscripción de club — campo `clubs` del pending endpoint.
///
/// Campos relevantes del backend:
///   camporee_club_id, camporee_id, club_section_id, section_name,
///   club_name, status, registered_by_name, created_at, rejection_reason
class CamporeeClubEnrollmentModel extends Equatable {
  final int camporeeClubId;
  final int camporeeId;
  final int clubSectionId;
  final String? sectionName;
  final String? clubName;
  final CamporeeApprovalStatus status;
  final String? registeredByName;
  final DateTime? createdAt;
  final String? rejectionReason;

  const CamporeeClubEnrollmentModel({
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

  factory CamporeeClubEnrollmentModel.fromJson(
    Map<String, dynamic> json, {
    required int camporeeId,
  }) {
    return CamporeeClubEnrollmentModel(
      camporeeClubId: (json['camporee_club_id'] ?? 0) as int,
      camporeeId: (json['camporee_id'] ?? camporeeId) as int,
      clubSectionId: (json['club_section_id'] ?? 0) as int,
      sectionName: json['section_name'] as String?,
      clubName: json['club_name'] as String?,
      status: CamporeeApprovalStatus.fromString(
        (json['status'] ?? 'pending_approval') as String,
      ),
      registeredByName:
          (json['registered_by_name'] ?? json['registered_by']) as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  CamporeeClubEnrollment toEntity() => CamporeeClubEnrollment(
        camporeeClubId: camporeeClubId,
        camporeeId: camporeeId,
        clubSectionId: clubSectionId,
        sectionName: sectionName,
        clubName: clubName,
        status: status,
        registeredByName: registeredByName,
        createdAt: createdAt,
        rejectionReason: rejectionReason,
      );

  @override
  List<Object?> get props =>
      [camporeeClubId, camporeeId, clubSectionId, status];
}

// ── CamporeeMemberEnrollmentModel ─────────────────────────────────────────────

/// Modelo para una inscripción de miembro — campo `members` del pending endpoint.
///
/// Campos relevantes del backend:
///   user_id, camporee_member_id, name, picture_url, club_name,
///   status, rejection_reason
class CamporeeMemberEnrollmentModel extends Equatable {
  final int camporeeMemberId;
  final String userId;
  final int camporeeId;
  final String? memberName;
  final String? clubName;
  final String? pictureUrl;
  final CamporeeApprovalStatus status;
  final DateTime? createdAt;
  final String? rejectionReason;

  const CamporeeMemberEnrollmentModel({
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

  factory CamporeeMemberEnrollmentModel.fromJson(
    Map<String, dynamic> json, {
    required int camporeeId,
  }) {
    return CamporeeMemberEnrollmentModel(
      camporeeMemberId: (json['camporee_member_id'] ?? 0) as int,
      userId: (json['user_id'] ?? '') as String,
      camporeeId: camporeeId,
      memberName: (json['name'] ?? json['member_name']) as String?,
      clubName: json['club_name'] as String?,
      pictureUrl: json['picture_url'] as String?,
      status: CamporeeApprovalStatus.fromString(
        (json['status'] ?? 'pending_approval') as String,
      ),
      createdAt: null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  CamporeeMemberEnrollment toEntity() => CamporeeMemberEnrollment(
        camporeeMemberId: camporeeMemberId,
        userId: userId,
        camporeeId: camporeeId,
        memberName: memberName,
        clubName: clubName,
        pictureUrl: pictureUrl,
        status: status,
        createdAt: createdAt,
        rejectionReason: rejectionReason,
      );

  @override
  List<Object?> get props =>
      [camporeeMemberId, userId, camporeeId, status];
}

// ── CamporeePaymentEnrollmentModel ────────────────────────────────────────────

/// Modelo para un pago de inscripción — campo `payments` del pending endpoint.
///
/// Campos relevantes del backend:
///   payment_id, camporee_payment_id, camporee_id, member_id, member_name,
///   amount, payment_type, reference, notes, status, created_at, rejection_reason
class CamporeePaymentEnrollmentModel extends Equatable {
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

  const CamporeePaymentEnrollmentModel({
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

  factory CamporeePaymentEnrollmentModel.fromJson(
    Map<String, dynamic> json, {
    required int camporeeId,
  }) {
    return CamporeePaymentEnrollmentModel(
      paymentId: (json['payment_id'] ?? 0) as int,
      camporeePaymentId: json['camporee_payment_id'] as String?,
      camporeeId: (json['camporee_id'] ?? camporeeId) as int,
      memberId: (json['member_id'] ?? '') as String,
      memberName: json['member_name'] as String?,
      amount: ((json['amount'] ?? 0) as num).toDouble(),
      paymentType: (json['payment_type'] ?? 'inscription') as String,
      reference: json['reference'] as String?,
      notes: json['notes'] as String?,
      status: CamporeeApprovalStatus.fromString(
        (json['status'] ?? 'pending_approval') as String,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  CamporeePaymentEnrollment toEntity() => CamporeePaymentEnrollment(
        paymentId: paymentId,
        camporeePaymentId: camporeePaymentId,
        camporeeId: camporeeId,
        memberId: memberId,
        memberName: memberName,
        amount: amount,
        paymentType: paymentType,
        reference: reference,
        notes: notes,
        status: status,
        createdAt: createdAt,
        rejectionReason: rejectionReason,
      );

  @override
  List<Object?> get props => [paymentId, camporeeId, memberId, status];
}
