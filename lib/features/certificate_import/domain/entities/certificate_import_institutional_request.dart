import 'package:equatable/equatable.dart';

/// Solicitud institucional (GM-02 / GM-03). Aprobar NO crea inscripción.
class CertificateImportInstitutionalRequest extends Equatable {
  final String id;
  final String status;
  final String? classAssetCode;
  final String? className;
  final String? decisionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const CertificateImportInstitutionalRequest({
    required this.id,
    required this.status,
    this.classAssetCode,
    this.className,
    this.decisionReason,
    this.createdAt,
    this.reviewedAt,
  });

  bool get isInstitutionalClass {
    final code = (classAssetCode ?? '').toUpperCase();
    return code == 'GM-02' || code == 'GM-03';
  }

  @override
  List<Object?> get props => [
        id,
        status,
        classAssetCode,
        className,
        decisionReason,
        createdAt,
        reviewedAt,
      ];
}

class CertificateImportInstitutionalRequestList extends Equatable {
  final List<CertificateImportInstitutionalRequest> items;
  final int total;
  final int page;
  final int limit;

  const CertificateImportInstitutionalRequestList({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  @override
  List<Object?> get props => [items, total, page, limit];
}
