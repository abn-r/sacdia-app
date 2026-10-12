import 'package:sacdia_app/core/widgets/instructor_selection.dart';

import '../../../../core/utils/json_helpers.dart';
import '../../domain/entities/instructor_proposal.dart';

/// Parses the `instructor_proposal` block of a user honor, and the body the
/// `POST .../instructor-proposal` answers. Tolerant: every field is optional
/// and anything unreadable is left out. Returns null only when [raw] is not
/// an object (`null` means "no proposal").
InstructorProposal? parseInstructorProposal(Object? raw) {
  if (raw is! Map) return null;
  return InstructorProposal(
    proposalId: safeStringOrNull(raw['proposal_id']),
    status: instructorProposalStatusFromApi(safeStringOrNull(raw['status'])),
    instructor: _parseProposed(raw['instructor']),
    rejectionReason: _text(raw['rejection_reason']),
    createdAt: _date(raw['created_at']),
    reviewedAt: _date(raw['reviewed_at']),
  );
}

String? _text(Object? raw) {
  final text = safeStringOrNull(raw)?.trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _date(Object? raw) {
  final text = safeStringOrNull(raw);
  return text == null ? null : DateTime.tryParse(text);
}

InstructorSelection? _parseProposed(Object? block) {
  if (block is! Map) return null;
  final name = _text(block['display_name']);
  if (name == null) return null;
  final kind = safeStringOrNull(block['kind'])?.toUpperCase();
  final userId = safeStringOrNull(block['user_id']);
  if (kind == 'EXTERNAL') return InstructorSelection.external(name);
  final hasId = userId != null && userId.isNotEmpty;
  if (hasId && (kind == 'USER' || kind == null)) {
    return InstructorSelection.user(
      id: userId,
      displayName: name,
      photoUrl: _text(block['photo_url']),
    );
  }
  return kind == null ? InstructorSelection.external(name) : null;
}
