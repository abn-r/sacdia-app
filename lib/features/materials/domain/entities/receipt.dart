import 'package:equatable/equatable.dart';

import 'material_receipt_status.dart';

/// Receipt uploaded by a director for an approved order.
class Receipt extends Equatable {
  final String id;
  final String orderId;
  final String r2Key;
  final String fileName;
  final String mimeType;
  final int sizeBytes;

  /// Monto declarado por el director en centavos (MXN).
  final int montoCentavos;

  final String? refBancariaDeclarada;
  final DateTime? fechaPago;
  final MaterialReceiptStatus status;

  /// URL firmada de R2 con TTL 15 minutos. Null si no está disponible.
  final String? signedUrl;

  final String uploadedBy;
  final String? validatedBy;
  final String? rejectReason;
  final DateTime createdAt;
  final DateTime? validatedAt;

  const Receipt({
    required this.id,
    required this.orderId,
    required this.r2Key,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.montoCentavos,
    this.refBancariaDeclarada,
    this.fechaPago,
    required this.status,
    this.signedUrl,
    required this.uploadedBy,
    this.validatedBy,
    this.rejectReason,
    required this.createdAt,
    this.validatedAt,
  });

  bool get isPending => status == MaterialReceiptStatus.pendiente;
  bool get isApproved => status == MaterialReceiptStatus.aprobado;
  bool get isRejected => status == MaterialReceiptStatus.rechazado;

  @override
  List<Object?> get props => [
        id,
        orderId,
        r2Key,
        fileName,
        mimeType,
        sizeBytes,
        montoCentavos,
        refBancariaDeclarada,
        fechaPago,
        status,
        signedUrl,
        uploadedBy,
        validatedBy,
        rejectReason,
        createdAt,
        validatedAt,
      ];
}
