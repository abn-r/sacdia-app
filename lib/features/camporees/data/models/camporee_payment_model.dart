import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee_payment.dart';
import '../../../../core/utils/json_helpers.dart';

/// Modelo de pago de camporee para la capa de datos
class CamporeePaymentModel extends Equatable {
  final int id;
  final int camporeeId;
  final String memberId;
  final double amount;
  final String paymentType;
  final String? reference;
  final String status;
  final DateTime? paymentDate;
  final String? notes;
  final DateTime? createdAt;

  const CamporeePaymentModel({
    required this.id,
    required this.camporeeId,
    required this.memberId,
    required this.amount,
    required this.paymentType,
    this.reference,
    required this.status,
    this.paymentDate,
    this.notes,
    this.createdAt,
  });

  factory CamporeePaymentModel.fromJson(Map<String, dynamic> json) {
    return CamporeePaymentModel(
      id: safeInt(json['id'] ?? json['payment_id']),
      camporeeId: safeInt(json['camporee_id']),
      memberId: safeString(json['member_id'] ?? json['user_id']),
      amount: safeDouble(json['amount']),
      paymentType: safeString(json['payment_type'], 'cash'),
      reference: safeStringOrNull(json['reference']),
      status: safeString(json['status'], 'pending'),
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(safeString(json['payment_date']))
          : null,
      notes: safeStringOrNull(json['notes']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(safeString(json['created_at']))
          : null,
    );
  }

  CamporeePayment toEntity() {
    return CamporeePayment(
      id: id,
      camporeeId: camporeeId,
      memberId: memberId,
      amount: amount,
      paymentType: paymentType,
      reference: reference,
      status: status,
      paymentDate: paymentDate,
      notes: notes,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        camporeeId,
        memberId,
        amount,
        paymentType,
        reference,
        status,
        paymentDate,
        notes,
        createdAt,
      ];
}

/// Modelo del club inscrito en un camporee
class CamporeeEnrolledClubModel extends Equatable {
  final int id;
  final int camporeeId;
  final int clubSectionId;
  final String? clubName;
  final String? sectionName;
  final DateTime? enrolledAt;

  const CamporeeEnrolledClubModel({
    required this.id,
    required this.camporeeId,
    required this.clubSectionId,
    this.clubName,
    this.sectionName,
    this.enrolledAt,
  });

  factory CamporeeEnrolledClubModel.fromJson(Map<String, dynamic> json) {
    final club = json['club'] as Map<String, dynamic>?;
    final section = json['club_section'] as Map<String, dynamic>?;

    return CamporeeEnrolledClubModel(
      id: safeInt(json['id'] ?? json['enrollment_id']),
      camporeeId: safeInt(json['camporee_id']),
      clubSectionId: safeInt(json['club_section_id'] ?? section?['id']),
      clubName: safeStringOrNull(club?['name']) ?? safeStringOrNull(json['club_name']),
      sectionName:
          safeStringOrNull(section?['name']) ?? safeStringOrNull(json['section_name']),
      enrolledAt: json['created_at'] != null
          ? DateTime.tryParse(safeString(json['created_at']))
          : null,
    );
  }

  CamporeeEnrolledClub toEntity() {
    return CamporeeEnrolledClub(
      id: id,
      camporeeId: camporeeId,
      clubSectionId: clubSectionId,
      clubName: clubName,
      sectionName: sectionName,
      enrolledAt: enrolledAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        camporeeId,
        clubSectionId,
        clubName,
        sectionName,
        enrolledAt,
      ];
}
