import 'package:equatable/equatable.dart';
import '../../domain/entities/evidence_review_item.dart';

/// Primer valor no nulo de [keys] en [json], convertido a String.
///
/// El backend devuelve ids numéricos (`id`, `evidence_file_id`) y algunos
/// campos pueden llegar como `num`; nunca castear con `as String`.
String? _readString(Map<String, dynamic>? json, List<String> keys) {
  if (json == null) return null;
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString();
    if (text.isNotEmpty) return text;
  }
  return null;
}

int? _readInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return null;
}

DateTime? _readDate(Map<String, dynamic> json, List<String> keys) {
  final raw = _readString(json, keys);
  return raw == null ? null : DateTime.tryParse(raw);
}

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
      id: _readString(json, const ['id', 'evidence_file_id', 'file_id']) ?? '',
      url: _readString(json, const ['url', 'file_url']) ?? '',
      name: _readString(json, const ['name', 'file_name']),
      mimeType: _readString(
        json,
        const ['mimeType', 'mime_type', 'content_type', 'file_type'],
      ),
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
      id: _readString(json, const ['id']) ?? '',
      action: _readString(json, const ['action']) ?? '',
      actorName: _readString(
        json,
        const ['actorName', 'actor_name', 'performed_by_name'],
      ),
      comment: _readString(
        json,
        const ['comment', 'comments', 'rejection_reason'],
      ),
      createdAt:
          _readDate(json, const ['createdAt', 'created_at']) ?? DateTime.now(),
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
  final bool memberIsDeleted;
  final String? memberPhotoUrl;
  final String? context;
  final String? clubSectionLabel;
  final DateTime submittedAt;
  final int fileCount;
  final List<EvidenceFileModel> files;
  final List<EvidenceHistoryEntryModel> history;

  const EvidenceReviewItemModel({
    required this.id,
    required this.type,
    required this.status,
    required this.memberName,
    this.memberIsDeleted = false,
    this.memberPhotoUrl,
    this.context,
    this.clubSectionLabel,
    required this.submittedAt,
    required this.fileCount,
    this.files = const [],
    this.history = const [],
  });

  factory EvidenceReviewItemModel.fromJson(Map<String, dynamic> json) {
    final typeStr =
        _readString(json, const ['type', 'evidence_type']) ?? 'class';
    final statusStr =
        _readString(json, const ['status', 'review_status']) ?? 'pending';
    final type = EvidenceReviewType.fromString(typeStr);

    final userRaw = json['user'];
    final user = userRaw is Map<String, dynamic> ? userRaw : null;
    final memberName = _readString(user, const ['name', 'full_name']) ??
        _readString(json, const ['member_name', 'memberName']) ??
        '';
    final memberIsDeleted =
        json['member_is_deleted'] == true || user?['is_deleted'] == true;
    final memberPhotoUrl = _readString(user, const ['photo_url', 'avatar']) ??
        _readString(json, const ['member_photo_url']);

    final filesRaw = json['files'];
    final files = filesRaw is List
        ? filesRaw
            .whereType<Map<String, dynamic>>()
            .map(EvidenceFileModel.fromJson)
            .toList()
        : <EvidenceFileModel>[];

    final historyRaw = json['history'];
    final history = historyRaw is List
        ? historyRaw
            .whereType<Map<String, dynamic>>()
            .map(EvidenceHistoryEntryModel.fromJson)
            .toList()
        : <EvidenceHistoryEntryModel>[];

    return EvidenceReviewItemModel(
      id: _readString(json, const ['id', 'review_id']) ?? '',
      type: type,
      status: EvidenceReviewStatus.fromString(statusStr),
      memberName: memberName,
      memberIsDeleted: memberIsDeleted,
      memberPhotoUrl: memberPhotoUrl,
      context: _readContext(json, type),
      clubSectionLabel: _readClubSectionLabel(json),
      submittedAt: _readDate(json, const ['submittedAt', 'submitted_at']) ??
          DateTime.now(),
      fileCount:
          _readInt(json, const ['fileCount', 'file_count']) ?? files.length,
      files: files,
      history: history,
    );
  }

  /// Qué se revisa: clase + sección del programa, o la especialidad.
  ///
  /// En el payload, `section_name` es la sección del programa de clase (o la
  /// especialidad en honores), NO la sección del club.
  static String? _readContext(
    Map<String, dynamic> json,
    EvidenceReviewType type,
  ) {
    final explicit = _readString(json, const ['context']);
    if (explicit != null) return explicit;

    if (type == EvidenceReviewType.honor) {
      return _readString(
        json,
        const ['entity_name', 'honor_name', 'section_name'],
      );
    }

    final entity = _readString(json, const ['entity_name', 'class_name']);
    final section = _readString(json, const ['section_name']);
    final parts = [entity, section].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Club y sección de club del miembro (p. ej. "Club Orión · Conquistadores").
  static String? _readClubSectionLabel(Map<String, dynamic> json) {
    final parts = [
      _readString(json, const ['club_name']),
      _readString(json, const ['club_section_name']),
    ].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  EvidenceReviewItem toEntity() => EvidenceReviewItem(
        id: id,
        type: type,
        status: status,
        memberName: memberName,
        memberIsDeleted: memberIsDeleted,
        memberPhotoUrl: memberPhotoUrl,
        context: context,
        clubSectionLabel: clubSectionLabel,
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
        memberIsDeleted,
        memberPhotoUrl,
        context,
        clubSectionLabel,
        submittedAt,
        fileCount,
        files,
        history,
      ];
}
