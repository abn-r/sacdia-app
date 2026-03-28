import 'package:sacdia_app/core/utils/app_logger.dart';
import '../../domain/entities/validation.dart';

const String _tag = 'ValidationModel';

ValidationStatus _parseStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'pending_review':
      return ValidationStatus.pendingReview;
    case 'approved':
      return ValidationStatus.approved;
    case 'rejected':
      return ValidationStatus.rejected;
    case 'in_progress':
    default:
      return ValidationStatus.inProgress;
  }
}

class ValidationHistoryEntryModel extends ValidationHistoryEntry {
  const ValidationHistoryEntryModel({
    required super.id,
    required super.status,
    super.reviewerComment,
    super.reviewerName,
    required super.createdAt,
  });

  factory ValidationHistoryEntryModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final status = _parseStatus(json['status'] as String?);

    DateTime createdAt = DateTime.now();
    final rawDate = json['created_at'];
    if (rawDate is String) {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed == null) {
        AppLogger.w('Failed to parse date: $rawDate, using DateTime.now()', tag: _tag);
      }
      createdAt = parsed ?? DateTime.now();
    }

    return ValidationHistoryEntryModel(
      id: id,
      status: status,
      reviewerComment: json['reviewer_comment'] as String?,
      reviewerName: json['reviewer_name'] as String?,
      createdAt: createdAt,
    );
  }
}

class ValidationSubmitResultModel extends ValidationSubmitResult {
  const ValidationSubmitResultModel({
    required super.id,
    required super.status,
  });

  factory ValidationSubmitResultModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;
    final status = _parseStatus(json['status'] as String?);
    return ValidationSubmitResultModel(id: id, status: status);
  }
}

class EligibilityResultModel extends EligibilityResult {
  const EligibilityResultModel({
    required super.eligible,
    required super.completionPercent,
    super.reason,
  });

  factory EligibilityResultModel.fromJson(Map<String, dynamic> json) {
    final rawPercent = json['completion_percent'] ?? json['percentage'] ?? 0;
    final percent = rawPercent is double
        ? rawPercent
        : (rawPercent is int
            ? rawPercent.toDouble()
            : double.tryParse(rawPercent.toString()) ?? 0.0);

    return EligibilityResultModel(
      eligible: json['eligible'] as bool? ?? false,
      completionPercent: percent,
      reason: json['reason'] as String?,
    );
  }
}
