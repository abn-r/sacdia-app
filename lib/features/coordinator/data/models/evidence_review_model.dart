import 'package:equatable/equatable.dart';
import '../../domain/entities/evidence_review_item.dart';

class EvidenceFileModel extends Equatable {
  final String id;
  final String url;
  final String? name;
  final String? mimeType;

  const EvidenceFileModel({
    required this.id,
    required this.url,
    this.name,
    this.mimeType,
  });

  factory EvidenceFileModel.fromJson(Map<String, dynamic> json) {
    return EvidenceFileModel(
      id: (json['id'] ?? json['file_id'] ?? '') as String,
      url: (json['url'] ?? json['file_url'] ?? '') as String,
      name: json['name'] as String?,
      mimeType: (json['mimeType'] ?? json['mime_type'] ?? json['content_type'])
          as String?,
    );
  }

  EvidenceFile toEntity() => EvidenceFile(
        id: id,
        url: url,
        name: name,
        mimeType: mimeType,
      );

  @override
  List<Object?> get props => [id, url, name, mimeType];
}

class EvidenceHistoryEntryModel extends Equatable {
  final String id;
  final String action;
  final String? actorName;
  final String? comment;
  final DateTime createdAt;

  const EvidenceHistoryEntryModel({
    required this.id,
    required this.action,
    this.actorName,
    this.comment,
    required this.createdAt,
  });

  factory EvidenceHistoryEntryModel.fromJson(Map<String, dynamic> json) {
    return EvidenceHistoryEntryModel(
      id: (json['id'] ?? '') as String,
      action: (json['action'] ?? '') as String,
      actorName: (json['actorName'] ?? json['actor_name']) as String?,
      comment:
          (json['comment'] ?? json['comments'] ?? json['rejection_reason'])
              as String?,
      createdAt: DateTime.tryParse(
              (json['createdAt'] ?? json['created_at'] ?? '') as String) ??
          DateTime.now(),
    );
  }

  EvidenceHistoryEntry toEntity() => EvidenceHistoryEntry(
        id: id,
        action: action,
        actorName: actorName,
        comment: comment,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, action, actorName, comment, createdAt];
}

/// Modelo de ítem de revisión de evidencia.
///
/// Mapea la respuesta de GET /evidence-review/pending y GET /evidence-review/:type/:id.
class EvidenceReviewItemModel extends Equatable {
  final String id;
  final EvidenceReviewType type;
  final EvidenceReviewStatus status;
  final String memberName;
  final String? memberPhotoUrl;
  final String? context;
  final DateTime submittedAt;
  final int fileCount;
  final List<EvidenceFileModel> files;
  final List<EvidenceHistoryEntryModel> history;

  const EvidenceReviewItemModel({
    required this.id,
    required this.type,
    required this.status,
    required this.memberName,
    this.memberPhotoUrl,
    this.context,
    required this.submittedAt,
    required this.fileCount,
    this.files = const [],
    this.history = const [],
  });

  factory EvidenceReviewItemModel.fromJson(Map<String, dynamic> json) {
    final typeStr =
        (json['type'] ?? json['evidence_type'] ?? 'folder') as String;
    final statusStr =
        (json['status'] ?? json['review_status'] ?? 'pending') as String;

    final user = json['user'] as Map<String, dynamic>?;
    final memberName = (user?['name'] ??
            user?['full_name'] ??
            json['member_name'] ??
            json['memberName'] ??
            '') as String;
    final memberPhotoUrl = (user?['photo_url'] ??
        user?['avatar'] ??
        json['member_photo_url']) as String?;

    final filesRaw = json['files'];
    final files = filesRaw is List
        ? filesRaw
            .map((e) =>
                EvidenceFileModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <EvidenceFileModel>[];

    final historyRaw = json['history'];
    final history = historyRaw is List
        ? historyRaw
            .map((e) =>
                EvidenceHistoryEntryModel.fromJson(e as Map<String, dynamic>))
            .toList()
        : <EvidenceHistoryEntryModel>[];

    return EvidenceReviewItemModel(
      id: (json['id'] ?? json['review_id'] ?? '') as String,
      type: EvidenceReviewType.fromString(typeStr),
      status: EvidenceReviewStatus.fromString(statusStr),
      memberName: memberName,
      memberPhotoUrl: memberPhotoUrl,
      context: (json['context'] ?? json['class_name'] ?? json['honor_name'])
          as String?,
      submittedAt: DateTime.tryParse(
              (json['submittedAt'] ?? json['submitted_at'] ?? '') as String) ??
          DateTime.now(),
      fileCount: (json['fileCount'] ?? json['file_count'] ?? files.length)
              as int? ??
          files.length,
      files: files,
      history: history,
    );
  }

  EvidenceReviewItem toEntity() => EvidenceReviewItem(
        id: id,
        type: type,
        status: status,
        memberName: memberName,
        memberPhotoUrl: memberPhotoUrl,
        context: context,
        submittedAt: submittedAt,
        fileCount: fileCount,
        files: files.map((f) => f.toEntity()).toList(),
        history: history.map((h) => h.toEntity()).toList(),
      );

  @override
  List<Object?> get props => [
        id,
        type,
        status,
        memberName,
        memberPhotoUrl,
        context,
        submittedAt,
        fileCount,
        files,
        history,
      ];
}
