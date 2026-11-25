import '../../domain/entities/supervision_folder.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _str(Object? v) {
  if (v == null || v is Map || v is List) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String _text(Object? v) => _str(v) ?? '';

int? _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) {
    return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  }
  return null;
}

double? _double(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

bool _bool(Object? v) => v == true || v == 'true' || v == 1;

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

/// A person field may be a display name, an id or an object with name parts.
/// Numbers are treated as ids and yield null.
String? _personName(Object? v) {
  if (v is String) {
    final s = v.trim();
    return s.isEmpty ? null : s;
  }
  final m = _map(v);
  if (m == null) return null;
  final full = _str(m['full_name'])?.trim();
  if (full != null && full.isNotEmpty) return full;
  final parts = [
    _str(m['name']),
    _str(m['paternal_last_name']),
    _str(m['maternal_last_name']),
  ].whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty);
  final joined = parts.join(' ');
  return joined.isEmpty ? null : joined;
}

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? v.map(_map).whereType<Map<String, dynamic>>().toList()
    : const [];

class SupervisionFolderModel {
  const SupervisionFolderModel._();

  /// Returns null only when the item has no usable id.
  static SupervisionFolderQueueItem? tryParseQueueItem(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _str(json['annual_folder_id']);
    if (id == null) return null;
    final names = json['pending_section_names'];
    return SupervisionFolderQueueItem(
      id: id,
      displayName: _text(json['display_name']),
      clubName: _text(json['club_name']),
      sectionName: _text(json['club_section_name']),
      clubTypeName: _text(json['club_type_name']),
      localFieldName: _text(json['local_field_name']),
      unionName: _text(json['union_name']),
      templateName: _text(json['template_name']),
      yearLabel: _text(json['year_label']),
      folderStatus: SupervisionFolderStatus.parse(json['folder_status']),
      totalSections: _int(json['total_sections']) ?? 0,
      submittedSections: _int(json['submitted_sections_count']) ?? 0,
      preapprovedSections: _int(json['preapproved_sections_count']) ?? 0,
      validatedSections: _int(json['validated_sections_count']) ?? 0,
      rejectedSections: _int(json['rejected_sections_count']) ?? 0,
      pendingSectionNames: names is List
          ? names.map(_str).whereType<String>().toList()
          : const [],
      latestSubmittedAt: _date(json['latest_submitted_at']),
      createdAt: _date(json['created_at']),
    );
  }

  /// Parses the nested `{data: [...], total, page, limit}` paging object.
  static SupervisionFolderQueuePage parseQueuePage(Object? raw) {
    final json = _map(raw) ?? const <String, dynamic>{};
    final items = _maps(json['data'])
        .map(tryParseQueueItem)
        .whereType<SupervisionFolderQueueItem>()
        .toList();
    return SupervisionFolderQueuePage(
      items: items,
      total: _int(json['total']) ?? items.length,
      page: _int(json['page']) ?? 1,
      limit: _int(json['limit']) ?? items.length,
    );
  }

  static SupervisionFolderEvidence? tryParseEvidence(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _str(json['evidence_id']);
    if (id == null) return null;
    return SupervisionFolderEvidence(
      id: id,
      fileUrl: _text(json['file_url']),
      fileName: _text(json['file_name']),
      notes: _str(json['notes']),
      reviewerNote: _str(json['reviewer_note']),
      reviewerNotedByName: _personName(json['reviewer_noted_by']),
      reviewerNotedAt: _date(json['reviewer_noted_at']),
      uploadedByName: _personName(json['uploaded_by']),
      createdAt: _date(json['created_at']),
    );
  }

  /// Status follows the member-side model: the section `status` (or the
  /// evaluation status) when present; otherwise `submitted` if a submission
  /// exists, else `pending`.
  static SupervisionFolderSection? tryParseSection(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _str(json['section_id']);
    if (id == null) return null;
    final evaluation = _map(json['evaluation']);
    final submission = _map(json['submission']);
    final rawStatus = json['status'] ?? evaluation?['status'];
    final status = rawStatus != null
        ? SupervisionSectionStatus.parse(rawStatus)
        : submission != null
            ? SupervisionSectionStatus.submitted
            : SupervisionSectionStatus.pending;

    Object? pick(String key) => evaluation?[key] ?? json[key];

    return SupervisionFolderSection(
      id: id,
      name: _text(json['name']),
      description: _str(json['description']),
      order: _int(json['order']) ?? 0,
      isRequired: _bool(json['required']),
      maxPoints:
          _int(json['max_points']) ?? _int(evaluation?['max_points']) ?? 0,
      minimumPoints: _int(json['minimum_points']),
      status: status,
      earnedPoints: _int(evaluation?['earned_points']),
      evaluationNotes: _str(evaluation?['notes']),
      lfApproverName: _personName(pick('lf_approver')),
      lfApprovedAt: _date(pick('lf_approved_at')),
      unionApproverName: _personName(pick('union_approver')),
      unionApprovedAt: _date(pick('union_approved_at')),
      unionDecision: _str(pick('union_decision')),
      submittedAt: _date(submission?['submitted_at']),
      evidences: _maps(json['evidences'])
          .map(tryParseEvidence)
          .whereType<SupervisionFolderEvidence>()
          .toList(),
    );
  }

  /// Returns null only when the folder has no usable id.
  static SupervisionFolderDetail? tryParseDetail(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    final id = _str(json['annual_folder_id']);
    if (id == null) return null;
    final enrollment = _map(json['club_enrollment']);
    final section = _map(enrollment?['club_section']);
    final club = _map(section?['club']);
    final localField = _map(club?['local_field']);
    final sections = _maps(json['sections'])
        .map(tryParseSection)
        .whereType<SupervisionFolderSection>()
        .toList();
    final indexed = sections.asMap().entries.toList()
      ..sort((a, b) {
        final byOrder = a.value.order.compareTo(b.value.order);
        return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
      });
    return SupervisionFolderDetail(
      id: id,
      status: SupervisionFolderStatus.parse(json['status']),
      clubName: _text(club?['name']),
      sectionName: _text(section?['name']),
      clubTypeName: _text(_map(section?['club_type'])?['name']),
      localFieldName: _text(localField?['name']),
      unionName: _text(_map(localField?['union'])?['name']),
      templateName: _text(_map(json['template'])?['name']),
      yearLabel: _text(_map(enrollment?['ecclesiastical_year'])?['label']),
      totalEarnedPoints: _int(json['total_earned_points']) ?? 0,
      totalMaxPoints: _int(json['total_max_points']) ?? 0,
      progressPercentage: _double(json['progress_percentage']) ?? 0,
      requiresUnionConfirmation: _bool(json['requires_union_confirmation']),
      submittedAt: _date(json['submitted_at']),
      closedAt: _date(json['closed_at']),
      evaluatedAt: _date(json['evaluated_at']),
      sections: indexed.map((e) => e.value).toList(),
    );
  }
}
