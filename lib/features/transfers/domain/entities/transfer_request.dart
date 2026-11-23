import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

/// Estado de una solicitud de traslado.
enum TransferStatus { pending, approved, rejected }

extension TransferStatusX on TransferStatus {
  String get label {
    switch (this) {
      case TransferStatus.pending:
        return tr('domain.statuses.pending');
      case TransferStatus.approved:
        return tr('domain.statuses.approved');
      case TransferStatus.rejected:
        return tr('domain.statuses.rejected');
    }
  }

  String get slug {
    switch (this) {
      case TransferStatus.pending:
        return 'pending';
      case TransferStatus.approved:
        return 'approved';
      case TransferStatus.rejected:
        return 'rejected';
    }
  }
}

/// Entidad de dominio para una solicitud de traslado entre secciones.
class TransferRequest extends Equatable {
  final String id;
  final int toSectionId;
  final String? toSectionName;
  final String? toClubName;
  final String? fromSectionName;
  final String? fromClubName;
  final String? reason;
  final TransferStatus status;
  final String? reviewerComment;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const TransferRequest({
    required this.id,
    required this.toSectionId,
    this.toSectionName,
    this.toClubName,
    this.fromSectionName,
    this.fromClubName,
    this.reason,
    required this.status,
    this.reviewerComment,
    this.createdAt,
    this.reviewedAt,
  });

  /// First 8 characters of the id: enough to quote it to a director.
  String get folio => id.length > 8 ? id.substring(0, 8) : id;

  @override
  List<Object?> get props => [
        id,
        toSectionId,
        toSectionName,
        toClubName,
        fromSectionName,
        fromClubName,
        reason,
        status,
        reviewerComment,
        createdAt,
        reviewedAt,
      ];
}
