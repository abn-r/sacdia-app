class CertificateImportFilePayload {
  final String url;
  final String name;
  final String type;
  final String? ocrRawText;

  const CertificateImportFilePayload({
    required this.url,
    required this.name,
    required this.type,
    this.ocrRawText,
  });

  Map<String, dynamic> toJson() => {
        'file_url': url,
        'file_name': name,
        'file_type': type,
        if (ocrRawText != null) 'ocr_raw_text': ocrRawText,
      };
}

class CertificateImportItemUpdatePayload {
  final String itemType;
  final int? honorId;
  final int? classId;
  final String? detectedName;
  final String? detectedDate;
  final String? completedAt;
  final double? ocrConfidence;
  final Map<String, dynamic>? fieldConfidence;
  final bool markAsReady;

  const CertificateImportItemUpdatePayload({
    required this.itemType,
    this.honorId,
    this.classId,
    this.detectedName,
    this.detectedDate,
    this.completedAt,
    this.ocrConfidence,
    this.fieldConfidence,
    this.markAsReady = false,
  });

  Map<String, dynamic> toJson() => {
        'item_type': itemType,
        if (honorId != null) 'honor_id': honorId,
        if (classId != null) 'class_id': classId,
        if (detectedName != null) 'detected_name': detectedName,
        if (detectedDate != null) 'detected_date': detectedDate,
        if (completedAt != null) 'completed_at': completedAt,
        if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
        if (fieldConfidence != null) 'field_confidence': fieldConfidence,
        'mark_as_ready': markAsReady,
      };
}
