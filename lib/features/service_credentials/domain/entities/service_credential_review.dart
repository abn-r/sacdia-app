import 'package:equatable/equatable.dart';

import 'service_credential.dart';

/// Pestaña de la cola de revisión.
enum ReviewStatusFilter {
  pending('PENDING_REVIEW'),
  approved('APPROVED'),
  rejected('REJECTED');

  const ReviewStatusFilter(this.apiValue);

  final String apiValue;
}

/// Persona dueña de la constancia.
class ReviewPerson extends Equatable {
  const ReviewPerson({required this.userId, required this.name, this.photoUrl});

  final String userId;
  final String name;
  final String? photoUrl;

  @override
  List<Object?> get props => [userId, name, photoUrl];
}

/// Fila de la cola de revisión.
class ReviewItem extends Equatable {
  const ReviewItem({
    required this.id,
    required this.person,
    this.clubName,
    this.completedAt,
    this.status = ServiceCredentialStatus.unknown,
    this.createdAt,
    this.reviewedAt,
    this.reviewerRole,
  });

  final String id;
  final ReviewPerson person;
  final String? clubName;
  final DateTime? completedAt;
  final ServiceCredentialStatus status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final String? reviewerRole;

  @override
  List<Object?> get props => [
        id,
        person,
        clubName,
        completedAt,
        status,
        createdAt,
        reviewedAt,
        reviewerRole,
      ];
}

/// Conteos por estado de TODA la cola (no solo de lo cargado).
class ReviewCounts extends Equatable {
  const ReviewCounts({this.pending = 0, this.approved = 0, this.rejected = 0});

  final int pending;
  final int approved;
  final int rejected;

  int of(ReviewStatusFilter filter) => switch (filter) {
        ReviewStatusFilter.pending => pending,
        ReviewStatusFilter.approved => approved,
        ReviewStatusFilter.rejected => rejected,
      };

  @override
  List<Object?> get props => [pending, approved, rejected];
}

/// Una página de la cola.
class ReviewPage extends Equatable {
  const ReviewPage({
    required this.items,
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.counts = const ReviewCounts(),
  });

  final List<ReviewItem> items;
  final int page;
  final int limit;
  final int total;
  final ReviewCounts counts;

  @override
  List<Object?> get props => [items, page, limit, total, counts];
}

/// Detalle de una constancia por revisar, con el archivo firmado.
class ReviewDetail extends Equatable {
  const ReviewDetail({
    required this.item,
    this.fileUrl,
    this.mimeType,
    this.decisionReason,
    this.expiresAt,
  });

  final ReviewItem item;

  /// URL firmada (900 s). Nunca se guarda en disco.
  final String? fileUrl;
  final String? mimeType;
  final String? decisionReason;
  final DateTime? expiresAt;

  bool get isPdf => (mimeType ?? '').toLowerCase() == 'application/pdf';
  bool get isImage => (mimeType ?? '').toLowerCase().startsWith('image/');
  bool get hasFile => (fileUrl ?? '').isNotEmpty;

  @override
  List<Object?> get props =>
      [item, fileUrl, mimeType, decisionReason, expiresAt];
}
