import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

/// Estado de una solicitud de validación.
enum ValidationStatus {
  inProgress,
  pendingReview,
  approved,
  rejected,
}

/// Extensión para obtener etiqueta y color de [ValidationStatus].
extension ValidationStatusX on ValidationStatus {
  String get label {
    switch (this) {
      case ValidationStatus.inProgress:
        return tr('validation.status.inProgress');
      case ValidationStatus.pendingReview:
        return tr('validation.status.pendingReview');
      case ValidationStatus.approved:
        return tr('validation.status.approved');
      case ValidationStatus.rejected:
        return tr('validation.status.rejected');
    }
  }

  String get slug {
    switch (this) {
      case ValidationStatus.inProgress:
        return 'in_progress';
      case ValidationStatus.pendingReview:
        return 'pending_review';
      case ValidationStatus.approved:
        return 'approved';
      case ValidationStatus.rejected:
        return 'rejected';
    }
  }
}

/// Tipo de entidad que puede ser validada.
enum ValidationEntityType { classProgress, honor }

extension ValidationEntityTypeX on ValidationEntityType {
  String get slug {
    switch (this) {
      case ValidationEntityType.classProgress:
        return 'class_progress';
      case ValidationEntityType.honor:
        return 'honor';
    }
  }
}

/// Entrada en el historial de validaciones.
class ValidationHistoryEntry extends Equatable {
  final int id;
  final ValidationStatus status;
  final String? reviewerComment;
  final String? reviewerName;
  final DateTime createdAt;

  const ValidationHistoryEntry({
    required this.id,
    required this.status,
    this.reviewerComment,
    this.reviewerName,
    required this.createdAt,
  });

  @override
  List<Object?> get props =>
      [id, status, reviewerComment, reviewerName, createdAt];
}

/// Resultado del submit de validación.
class ValidationSubmitResult extends Equatable {
  final int id;
  final ValidationStatus status;

  const ValidationSubmitResult({
    required this.id,
    required this.status,
  });

  @override
  List<Object?> get props => [id, status];
}

/// Resultado de elegibilidad para investidura.
class EligibilityResult extends Equatable {
  final bool eligible;
  final double completionPercent;
  final String? reason;

  const EligibilityResult({
    required this.eligible,
    required this.completionPercent,
    this.reason,
  });

  @override
  List<Object?> get props => [eligible, completionPercent, reason];
}
