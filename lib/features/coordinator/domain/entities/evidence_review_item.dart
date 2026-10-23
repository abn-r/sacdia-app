import 'package:easy_localization/easy_localization.dart';
import 'package:equatable/equatable.dart';

/// Tamaño de página de GET /evidence-review/pending que pide la app.
const int kPendingEvidencePageSize = 20;

/// Tipo de evidencia que puede ser revisada.
enum EvidenceReviewType {
  classType,
  honor;

  static EvidenceReviewType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'class':
        return EvidenceReviewType.classType;
      case 'honor':
        return EvidenceReviewType.honor;
      default:
        return EvidenceReviewType.classType;
    }
  }

  String get apiValue {
    switch (this) {
      case EvidenceReviewType.classType:
        return 'class';
      case EvidenceReviewType.honor:
        return 'honor';
    }
  }

  String get displayLabel {
    switch (this) {
      case EvidenceReviewType.classType:
        return tr('coordinator.evidence_type.class_type');
      case EvidenceReviewType.honor:
        return tr('coordinator.evidence_type.honor');
    }
  }
}

/// Estado de revisión de una evidencia.
enum EvidenceReviewStatus {
  pending,
  approved,
  rejected;

  static EvidenceReviewStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'approved':
      case 'validated':
        return EvidenceReviewStatus.approved;
      case 'rejected':
        return EvidenceReviewStatus.rejected;
      case 'submitted':
      case 'pending_review':
      case 'pending':
      default:
        return EvidenceReviewStatus.pending;
    }
  }
}

/// Archivo adjunto a una evidencia.
class EvidenceFile extends Equatable {
  final String id;
  final String url;
  final String? name;
  final String? mimeType;

  const EvidenceFile({
    required this.id,
    required this.url,
    this.name,
    this.mimeType,
  });

  bool get isImage {
    final mt = mimeType?.toLowerCase() ?? '';
    return mt.startsWith('image/') ||
        url.toLowerCase().endsWith('.jpg') ||
        url.toLowerCase().endsWith('.jpeg') ||
        url.toLowerCase().endsWith('.png') ||
        url.toLowerCase().endsWith('.webp');
  }

  bool get isPdf {
    return (mimeType?.toLowerCase().contains('pdf') ?? false) ||
        url.toLowerCase().endsWith('.pdf');
  }

  @override
  List<Object?> get props => [id, url, name, mimeType];
}

/// Entrada del historial de validación de una evidencia.
class EvidenceHistoryEntry extends Equatable {
  final String id;
  final String action;
  final String? actorName;
  final String? comment;
  final DateTime createdAt;

  const EvidenceHistoryEntry({
    required this.id,
    required this.action,
    this.actorName,
    this.comment,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, action, actorName, comment, createdAt];
}

/// Entidad de ítem de revisión de evidencia.
///
/// Devuelto por GET /evidence-review/pending y GET /evidence-review/:type/:id.
class EvidenceReviewItem extends Equatable {
  final String id;
  final EvidenceReviewType type;
  final EvidenceReviewStatus status;
  final String memberName;
  final bool memberIsDeleted;
  final String? memberPhotoUrl;
  final String? context;

  /// Club y sección de club del miembro (no la sección del programa).
  final String? clubSectionLabel;
  final DateTime submittedAt;
  final int fileCount;
  final List<EvidenceFile> files;
  final List<EvidenceHistoryEntry> history;

  const EvidenceReviewItem({
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

  String get displayMemberName =>
      memberIsDeleted ? tr('common.deleted_account') : memberName;

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

/// Una página de GET /evidence-review/pending.
///
/// [total] es el número de evidencias pendientes en el servidor para el filtro
/// pedido (todas las páginas), no solo las de esta página. Es null si el
/// servidor no lo informó.
class EvidenceReviewPage extends Equatable {
  final List<EvidenceReviewItem> items;
  final int? total;
  final int page;
  final int limit;

  const EvidenceReviewPage({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  /// Sin [total], una página llena es la única señal de que puede haber más.
  bool get hasMore {
    final total = this.total;
    if (total == null) return items.length >= limit;
    return page * limit < total;
  }

  @override
  List<Object?> get props => [items, total, page, limit];
}
