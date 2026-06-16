import 'package:equatable/equatable.dart';

enum HonorCompletionMode { undecided, inApp, external }

extension HonorCompletionModeApi on HonorCompletionMode {
  String get apiValue {
    switch (this) {
      case HonorCompletionMode.inApp:
        return 'IN_APP';
      case HonorCompletionMode.external:
        return 'EXTERNAL';
      case HonorCompletionMode.undecided:
        return 'UNDECIDED';
    }
  }
}

HonorCompletionMode honorCompletionModeFromApi(String? value) {
  switch (value?.toUpperCase()) {
    case 'IN_APP':
      return HonorCompletionMode.inApp;
    case 'EXTERNAL':
      return HonorCompletionMode.external;
    default:
      return HonorCompletionMode.undecided;
  }
}

enum HonorFileUploadField { images, document }

extension HonorFileUploadFieldApi on HonorFileUploadField {
  String get multipartFieldName {
    switch (this) {
      case HonorFileUploadField.document:
        return 'document';
      case HonorFileUploadField.images:
        return 'images';
    }
  }
}

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
  final HonorCompletionMode completionMode;
  final String certificate;
  final List<String> images;
  final String? document;
  final DateTime date;

  // Validation audit fields
  final DateTime? submittedAt;
  final String? validatedById;
  final String? validatedByName;
  final String? validatedByRoleName;
  final String? validatedByRoleLabel;
  final DateTime? validatedAt;
  final String? rejectionReason;

  // Embedded honor details returned by GET /users/:userId/honors
  final String? honorName;
  final String? honorImageUrl;
  final String? honorCategoryName;
  final int? honorCategoryId;
  final int? honorSkillLevel;
  final int? honorClubTypeId;
  final String? honorClubTypeName;

  const UserHonor({
    required this.id,
    required this.honorId,
    required this.userId,
    this.active = true,
    this.validate = false,
    this.validationStatus = 'in_progress',
    this.completionMode = HonorCompletionMode.undecided,
    this.certificate = '',
    this.images = const [],
    this.document,
    required this.date,
    this.submittedAt,
    this.validatedById,
    this.validatedByName,
    this.validatedByRoleName,
    this.validatedByRoleLabel,
    this.validatedAt,
    this.rejectionReason,
    this.honorName,
    this.honorImageUrl,
    this.honorCategoryName,
    this.honorCategoryId,
    this.honorSkillLevel,
    this.honorClubTypeId,
    this.honorClubTypeName,
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

  /// Whether the external completed format has been uploaded.
  bool get hasCompletedFormat => document != null && document!.isNotEmpty;

  /// General evidence files uploaded through the external workflow.
  int get generalEvidenceCount => images.length;

  /// Whether the external workflow has at least one general evidence file.
  bool get hasGeneralEvidence => images.isNotEmpty;

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
        completionMode,
        certificate,
        images,
        document,
        date,
        submittedAt,
        validatedById,
        validatedByName,
        validatedByRoleName,
        validatedByRoleLabel,
        validatedAt,
        rejectionReason,
        honorName,
        honorImageUrl,
        honorCategoryName,
        honorCategoryId,
        honorSkillLevel,
        honorClubTypeId,
        honorClubTypeName,
      ];
}
