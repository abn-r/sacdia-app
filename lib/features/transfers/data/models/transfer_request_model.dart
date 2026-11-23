import '../../domain/entities/transfer_request.dart';

TransferStatus _parseStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'approved':
      return TransferStatus.approved;
    case 'rejected':
      return TransferStatus.rejected;
    case 'pending':
    default:
      return TransferStatus.pending;
  }
}

class TransferRequestModel extends TransferRequest {
  const TransferRequestModel({
    required super.id,
    required super.toSectionId,
    super.toSectionName,
    super.toClubName,
    super.fromSectionName,
    super.fromClubName,
    super.reason,
    required super.status,
    super.reviewerComment,
    super.createdAt,
    super.reviewedAt,
  });

  factory TransferRequestModel.fromJson(Map<String, dynamic> json) {
    final id = (json['transfer_request_id'] ?? json['id'] ?? json['request_id'])
            ?.toString() ??
        '';

    final rawSectionId = json['to_section_id'] ?? json['section_id'];
    final toSectionId = rawSectionId is int
        ? rawSectionId
        : int.tryParse(rawSectionId.toString()) ?? 0;

    final status = _parseStatus(json['status'] as String?);

    DateTime? parseDate(Object? raw) =>
        raw is String ? DateTime.tryParse(raw) : null;

    // to_section / from_section nested objects (optional)
    final sectionNested = json['to_section'] as Map<String, dynamic>?;
    final toSectionName =
        json['to_section_name'] as String? ?? _sectionTypeName(sectionNested);
    final toClubName =
        json['to_club_name'] as String? ?? _sectionClubName(sectionNested);
    final fromNested = json['from_section'] as Map<String, dynamic>?;

    return TransferRequestModel(
      id: id,
      toSectionId: toSectionId,
      toSectionName: toSectionName,
      toClubName: toClubName,
      fromSectionName:
          json['from_section_name'] as String? ?? _sectionTypeName(fromNested),
      fromClubName:
          json['from_club_name'] as String? ?? _sectionClubName(fromNested),
      reason: json['reason'] as String?,
      status: status,
      // The table column is `review_comment`.
      reviewerComment:
          (json['review_comment'] ?? json['reviewer_comment'])?.toString(),
      createdAt: parseDate(json['created_at']),
      reviewedAt: parseDate(json['reviewed_at']),
    );
  }

  static String? _sectionTypeName(Map<String, dynamic>? section) {
    final type = section?['club_types'] ?? section?['club_type'];
    return type is Map ? type['name'] as String? : null;
  }

  static String? _sectionClubName(Map<String, dynamic>? section) =>
      (section?['clubs'] as Map?)?['name'] as String? ??
      (section?['main_club'] as Map?)?['name'] as String?;
}
