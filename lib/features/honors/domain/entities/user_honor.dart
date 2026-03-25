import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

/// Entidad de especialidad de usuario del dominio.
///
/// Combina los datos del backend `users_honors` con helpers de display
/// para la UI de la app.
class UserHonor extends Equatable {
  final int id;
  final int honorId;
  final String userId;
  final bool active;
  final bool validate;
  final String validationStatus;
  final String certificate;
  final List<String> images;
  final String? document;
  final DateTime date;

  // Validation audit fields
  final DateTime? submittedAt;
  final String? validatedById;
  final DateTime? validatedAt;
  final String? rejectionReason;

  // Embedded honor details returned by GET /users/:userId/honors
  final String? honorName;
  final String? honorImageUrl;
  final String? honorCategoryName;
  final int? honorSkillLevel;

  const UserHonor({
    required this.id,
    required this.honorId,
    required this.userId,
    this.active = true,
    this.validate = false,
    this.validationStatus = 'in_progress',
    this.certificate = '',
    this.images = const [],
    this.document,
    required this.date,
    this.submittedAt,
    this.validatedById,
    this.validatedAt,
    this.rejectionReason,
    this.honorName,
    this.honorImageUrl,
    this.honorCategoryName,
    this.honorSkillLevel,
  });

  // ── Computed display helpers ─────────────────────────────────────────

  /// Display status combines backend validation_status with evidence presence.
  /// Backend stores: in_progress | pending_review | approved | rejected
  /// Display adds: inscripto (in_progress + no evidence) vs en_progreso (in_progress + evidence)
  String get displayStatus {
    if (validationStatus == 'approved') return 'validado';
    if (validationStatus == 'rejected') return 'rechazado';
    if (validationStatus == 'pending_review') return 'enviado';
    // in_progress: split by evidence presence
    if (images.isNotEmpty || (document != null && document!.isNotEmpty)) {
      return 'en_progreso';
    }
    return 'inscripto';
  }

  /// Color for the current display status (use for border-left, badges, headers).
  Color get statusColor {
    switch (displayStatus) {
      case 'validado':
        return AppColors.sacGreen;
      case 'enviado':
        return AppColors.sacYellow;
      case 'en_progreso':
      case 'rechazado':
        return AppColors.sacRed;
      case 'inscripto':
        return AppColors.sacBlue;
      default:
        return AppColors.sacGrey;
    }
  }

  /// Human-readable label for the current display status.
  String get statusLabel {
    switch (displayStatus) {
      case 'validado':
        return 'Validada';
      case 'enviado':
        return 'Enviada — en revision';
      case 'en_progreso':
        return 'En progreso';
      case 'rechazado':
        return 'Rechazada';
      case 'inscripto':
        return 'Inscripta — sin evidencia';
      default:
        return 'Disponible';
    }
  }

  /// Whether the honor has been fully validated/completed.
  bool get isCompleted => validationStatus == 'approved';

  /// Whether the user can submit (or resubmit) for review.
  bool get canSubmit =>
      validationStatus == 'in_progress' || validationStatus == 'rejected';

  /// Whether the honor is currently under review (read-only for member).
  bool get isUnderReview => validationStatus == 'pending_review';

  /// Whether there is evidence uploaded.
  bool get hasEvidence =>
      images.isNotEmpty || (document != null && document!.isNotEmpty);

  /// Total evidence file count.
  int get evidenceCount {
    int count = images.length;
    if (document != null && document!.isNotEmpty) count++;
    return count;
  }

  @override
  List<Object?> get props => [
        id,
        honorId,
        userId,
        active,
        validate,
        validationStatus,
        certificate,
        images,
        document,
        date,
        submittedAt,
        validatedById,
        validatedAt,
        rejectionReason,
        honorName,
        honorImageUrl,
        honorCategoryName,
        honorSkillLevel,
      ];
}
