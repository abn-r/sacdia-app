import 'package:equatable/equatable.dart';

/// A union camporee as seen by a territorial supervisor.
class SupervisionUnionCamporee extends Equatable {
  const SupervisionUnionCamporee({
    required this.id,
    this.name = '',
    this.description,
    this.startDate,
    this.endDate,
    this.place = '',
    this.unionName = '',
    this.active = true,
    this.ordersEnabled = false,
    this.ordersOpensAt,
    this.ordersDeadline,
  });

  final int id;
  final String name;
  final String? description;

  /// Calendar dates at local midnight (never shifted by timezone).
  final DateTime? startDate;
  final DateTime? endDate;

  /// Empty when blank or the server default "Lugar".
  final String place;

  /// Empty when missing.
  final String unionName;
  final bool active;
  final bool ordersEnabled;

  /// Instants (UTC from the server).
  final DateTime? ordersOpensAt;
  final DateTime? ordersDeadline;

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        startDate,
        endDate,
        place,
        unionName,
        active,
        ordersEnabled,
        ordersOpensAt,
        ordersDeadline,
      ];
}

/// What a pending item to decide is.
enum SupervisionCamporeeApprovalKind { club, member, payment }

class SupervisionCamporeePendingClub extends Equatable {
  const SupervisionCamporeePendingClub({
    required this.id,
    this.clubName = '',
    this.sectionName = '',
    this.registeredByName,
    this.createdAt,
  });

  /// `camporee_club_id`.
  final int id;
  final String clubName;

  /// Club type name.
  final String sectionName;
  final String? registeredByName;
  final DateTime? createdAt;

  @override
  List<Object?> get props =>
      [id, clubName, sectionName, registeredByName, createdAt];
}

class SupervisionCamporeePendingMember extends Equatable {
  const SupervisionCamporeePendingMember({
    required this.id,
    this.fullName = '',
    this.clubName = '',
    this.insuranceVerified = false,
    this.createdAt,
  });

  /// `camporee_member_id`.
  final int id;
  final String fullName;
  final String clubName;
  final bool insuranceVerified;
  final DateTime? createdAt;

  @override
  List<Object?> get props =>
      [id, fullName, clubName, insuranceVerified, createdAt];
}

enum SupervisionCamporeePaymentType {
  inscription,
  materials,
  other,
  unknown;

  static SupervisionCamporeePaymentType parse(Object? raw) {
    switch (raw is String ? raw.trim().toLowerCase() : null) {
      case 'inscription':
        return inscription;
      case 'materials':
        return materials;
      case 'other':
        return other;
      default:
        return unknown;
    }
  }
}

class SupervisionCamporeePendingPayment extends Equatable {
  const SupervisionCamporeePendingPayment({
    required this.id,
    this.memberName = '',
    this.clubName = '',
    this.amount = 0,
    this.type = SupervisionCamporeePaymentType.unknown,
    this.reference,
    this.notes,
    this.voucherUrl,
    this.paidAt,
    this.createdAt,
  });

  /// `camporee_payment_id` (UUID).
  final String id;
  final String memberName;
  final String clubName;
  final double amount;
  final SupervisionCamporeePaymentType type;
  final String? reference;
  final String? notes;
  final String? voucherUrl;

  /// Calendar date at local midnight.
  final DateTime? paidAt;
  final DateTime? createdAt;

  @override
  List<Object?> get props => [
        id,
        memberName,
        clubName,
        amount,
        type,
        reference,
        notes,
        voucherUrl,
        paidAt,
        createdAt,
      ];
}

/// Everything waiting for a decision in one union camporee.
class SupervisionCamporeePending extends Equatable {
  const SupervisionCamporeePending({
    this.clubs = const [],
    this.members = const [],
    this.payments = const [],
  });

  static const SupervisionCamporeePending empty = SupervisionCamporeePending();

  final List<SupervisionCamporeePendingClub> clubs;
  final List<SupervisionCamporeePendingMember> members;
  final List<SupervisionCamporeePendingPayment> payments;

  int get total => clubs.length + members.length + payments.length;

  @override
  List<Object?> get props => [clubs, members, payments];
}
