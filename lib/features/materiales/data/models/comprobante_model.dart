import '../../domain/entities/comprobante.dart';
import '../../domain/entities/material_comprobante_status.dart';

/// Modelo de datos para [Comprobante].
///
/// Mapea la respuesta JSON de GET /materiales/comprobantes/:folio.
class ComprobanteModel extends Comprobante {
  const ComprobanteModel({
    required super.id,
    required super.orderId,
    required super.r2Key,
    required super.fileName,
    required super.mimeType,
    required super.sizeBytes,
    required super.montoCentavos,
    super.refBancariaDeclarada,
    super.fechaPago,
    required super.status,
    super.signedUrl,
    required super.uploadedBy,
    super.validatedBy,
    super.rejectReason,
    required super.createdAt,
    super.validatedAt,
  });

  factory ComprobanteModel.fromJson(Map<String, dynamic> json) {
    DateTime? fechaPago;
    final rawFecha = json['fecha_pago'] ?? json['fechaPago'];
    if (rawFecha != null) {
      fechaPago = DateTime.tryParse(rawFecha.toString());
    }

    DateTime? validatedAt;
    final rawValidated = json['validated_at'] ?? json['validatedAt'];
    if (rawValidated != null) {
      validatedAt = DateTime.tryParse(rawValidated.toString());
    }

    return ComprobanteModel(
      id: (json['id'] ?? '').toString(),
      orderId: (json['order_id'] ?? json['orderId'] ?? '').toString(),
      r2Key: (json['r2_key'] ?? json['r2Key'] ?? '').toString(),
      fileName: (json['file_name'] ?? json['fileName'] ?? '').toString(),
      mimeType: (json['mime_type'] ?? json['mimeType'] ?? '').toString(),
      sizeBytes: (json['size_bytes'] ?? json['sizeBytes'] ?? 0) as int,
      montoCentavos:
          (json['monto_centavos'] ?? json['montoCentavos'] ?? 0) as int,
      refBancariaDeclarada:
          (json['ref_bancaria_declarada'] ?? json['refBancariaDeclarada'])
              ?.toString(),
      fechaPago: fechaPago,
      status: MaterialComprobanteStatusX.fromString(
        (json['status'] ?? 'pendiente').toString(),
      ),
      signedUrl:
          (json['signed_url'] ?? json['signedUrl'])?.toString(),
      uploadedBy: (json['uploaded_by'] ?? json['uploadedBy'] ?? '').toString(),
      validatedBy:
          (json['validated_by'] ?? json['validatedBy'])?.toString(),
      rejectReason:
          (json['reject_reason'] ?? json['rejectReason'])?.toString(),
      createdAt: DateTime.tryParse(
              (json['created_at'] ?? json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      validatedAt: validatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'r2_key': r2Key,
      'file_name': fileName,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
      'monto_centavos': montoCentavos,
      if (refBancariaDeclarada != null)
        'ref_bancaria_declarada': refBancariaDeclarada,
      if (fechaPago != null) 'fecha_pago': fechaPago!.toIso8601String(),
      'status': status.toApiString(),
      if (signedUrl != null) 'signed_url': signedUrl,
      'uploaded_by': uploadedBy,
      if (validatedBy != null) 'validated_by': validatedBy,
      if (rejectReason != null) 'reject_reason': rejectReason,
      'created_at': createdAt.toIso8601String(),
      if (validatedAt != null) 'validated_at': validatedAt!.toIso8601String(),
    };
  }

  Comprobante toEntity() => Comprobante(
        id: id,
        orderId: orderId,
        r2Key: r2Key,
        fileName: fileName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        montoCentavos: montoCentavos,
        refBancariaDeclarada: refBancariaDeclarada,
        fechaPago: fechaPago,
        status: status,
        signedUrl: signedUrl,
        uploadedBy: uploadedBy,
        validatedBy: validatedBy,
        rejectReason: rejectReason,
        createdAt: createdAt,
        validatedAt: validatedAt,
      );
}
