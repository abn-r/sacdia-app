import 'package:equatable/equatable.dart';
import '../../domain/entities/camporee_payment.dart';

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
      id: (json['id'] ?? json['payment_id']) as int,
      camporeeId: json['camporee_id'] as int? ?? 0,
      memberId: (json['member_id'] ?? json['user_id'] ?? '') as String,
      amount: (json['amount'] as num).toDouble(),
      paymentType: json['payment_type'] as String? ?? 'cash',
      reference: json['reference'] as String?,
      status: json['status'] as String? ?? 'pending',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
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

/// Modelo del club inscripto en un camporee
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
      id: (json['id'] ?? json['enrollment_id']) as int,
      camporeeId: json['camporee_id'] as int? ?? 0,
      clubSectionId: (json['club_section_id'] ??
              section?['id'] ??
              0) as int,
      clubName: club?['name'] as String? ?? json['club_name'] as String?,
      sectionName:
          section?['name'] as String? ?? json['section_name'] as String?,
      enrolledAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
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
