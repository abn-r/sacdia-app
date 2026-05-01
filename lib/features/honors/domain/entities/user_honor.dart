import 'package:easy_localization/easy_localization.dart';
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
  final int? honorCategoryId;
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
    this.honorCategoryId,
    this.honorSkillLevel,
  });

  // ── Computed display helpers ─────────────────────────────────────────

  /// Display status combines backend validation_status with evidence presence.
  /// Backend stores: in_progress | pending_review | approved | rejected (lowercase or uppercase).
  /// Display adds: inscrito (in_progress + no evidence) vs en_progreso (in_progress + evidence)
  String get displayStatus {
    final vs = validationStatus.toUpperCase();
    if (vs == 'APPROVED') return 'validado';
    if (vs == 'REJECTED') return 'rechazado';
    if (vs == 'PENDING_REVIEW') return 'enviado';
    // in_progress: split by evidence presence
    if (images.isNotEmpty || (document != null && document!.isNotEmpty)) {
      return 'en_progreso';
    }
    return 'inscrito';
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
      case 'inscrito':
        return AppColors.sacBlue;
      default:
        return AppColors.sacGrey;
    }
  }

  /// Human-readable label for the current display status.
  String get statusLabel {
    switch (displayStatus) {
      case 'validado':
        return tr('honors.user_status.validated');
      case 'enviado':
        return tr('honors.user_status.submitted');
      case 'en_progreso':
        return tr('honors.user_status.in_progress');
      case 'rechazado':
        return tr('honors.user_status.rejected');
      case 'inscrito':
        return tr('honors.user_status.enrolled');
      default:
        return tr('honors.user_status.available');
    }
  }

  /// Whether the honor has been fully validated/completed.
  bool get isCompleted => validationStatus.toUpperCase() == 'APPROVED';

  /// Whether the user can submit (or resubmit) for review.
  bool get canSubmit {
    final vs = validationStatus.toUpperCase();
    return vs == 'IN_PROGRESS' || vs == 'REJECTED';
  }

  /// Whether the honor is currently under review (read-only for member).
  bool get isUnderReview => validationStatus.toUpperCase() == 'PENDING_REVIEW';

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
        honorCategoryId,
        honorSkillLevel,
      ];
}
