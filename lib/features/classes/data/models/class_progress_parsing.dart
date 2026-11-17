import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/class_progress_summary.dart';

/// Parses `status_counts` defensively: a missing or malformed value means no
/// counts (all zero), never an exception, so older servers keep working.
RequirementStatusCounts parseStatusCounts(Object? raw) {
  if (raw is! Map) return RequirementStatusCounts.zero;
  return RequirementStatusCounts(
    validated: safeInt(raw['validated']),
    submitted: safeInt(raw['submitted']),
    rejected: safeInt(raw['rejected']),
    pending: safeInt(raw['pending']),
  );
}

Map<String, dynamic> statusCountsToJson(RequirementStatusCounts counts) => {
      'validated': counts.validated,
      'submitted': counts.submitted,
      'rejected': counts.rejected,
      'pending': counts.pending,
    };

/// Parses a `{user_id, name}` person, or null when absent or without id.
ClassResponsible? parseResponsible(Object? raw) {
  if (raw is! Map) return null;
  final userId = safeString(raw['user_id']);
  if (userId.isEmpty) return null;
  return ClassResponsible(userId: userId, name: safeString(raw['name']));
}

Map<String, dynamic>? responsibleToJson(ClassResponsible? person) =>
    person == null ? null : {'user_id': person.userId, 'name': person.name};

/// `avg_progress` clamped to 0-100.
int parseProgressPercent(Object? raw) => safeInt(raw).clamp(0, 100);
