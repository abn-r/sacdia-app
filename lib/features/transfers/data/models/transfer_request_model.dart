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
    super.reason,
    required super.status,
    super.reviewerComment,
    super.createdAt,
  });

  factory TransferRequestModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'] ?? json['request_id'];
    final id = rawId is int ? rawId : int.tryParse(rawId.toString()) ?? 0;

    final rawSectionId = json['to_section_id'] ?? json['section_id'];
    final toSectionId = rawSectionId is int
        ? rawSectionId
        : int.tryParse(rawSectionId.toString()) ?? 0;

    final status = _parseStatus(json['status'] as String?);

    DateTime? createdAt;
    final rawDate = json['created_at'];
    if (rawDate is String) createdAt = DateTime.tryParse(rawDate);

    // to_section nested object (optional)
    final sectionNested = json['to_section'] as Map<String, dynamic>?;
    final toSectionName = json['to_section_name'] as String? ??
        sectionNested?['name'] as String?;
    final toClubName = json['to_club_name'] as String? ??
        (sectionNested?['main_club'] as Map?)?['name'] as String?;

    return TransferRequestModel(
      id: id,
      toSectionId: toSectionId,
      toSectionName: toSectionName,
      toClubName: toClubName,
      reason: json['reason'] as String?,
      status: status,
      reviewerComment: json['reviewer_comment'] as String?,
      createdAt: createdAt,
    );
  }
}
