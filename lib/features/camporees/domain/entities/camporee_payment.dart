import 'package:equatable/equatable.dart';

/// Estado de un pago de camporee
enum CamporeePaymentStatus { pending, verified, rejected }

extension CamporeePaymentStatusX on CamporeePaymentStatus {
  String get label {
    switch (this) {
      case CamporeePaymentStatus.pending:
        return 'Pendiente';
      case CamporeePaymentStatus.verified:
        return 'Verificado';
      case CamporeePaymentStatus.rejected:
        return 'Rechazado';
    }
  }

  String get slug {
    switch (this) {
      case CamporeePaymentStatus.pending:
        return 'pending';
      case CamporeePaymentStatus.verified:
        return 'verified';
      case CamporeePaymentStatus.rejected:
        return 'rejected';
    }
  }
}

/// Entidad de pago de camporee
class CamporeePayment extends Equatable {
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

  const CamporeePayment({
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

  CamporeePaymentStatus get paymentStatus {
    switch (status) {
      case 'verified':
        return CamporeePaymentStatus.verified;
      case 'rejected':
        return CamporeePaymentStatus.rejected;
      default:
        return CamporeePaymentStatus.pending;
    }
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

/// Entidad del club inscrito en un camporee
class CamporeeEnrolledClub extends Equatable {
  final int id;
  final int camporeeId;
  final int clubSectionId;
  final String? clubName;
  final String? sectionName;
  final DateTime? enrolledAt;

  const CamporeeEnrolledClub({
    required this.id,
    required this.camporeeId,
    required this.clubSectionId,
    this.clubName,
    this.sectionName,
    this.enrolledAt,
  });

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
