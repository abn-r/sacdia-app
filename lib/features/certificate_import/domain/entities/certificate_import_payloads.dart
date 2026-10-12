import 'certificate_import_item.dart';

/// Local proof selected on device. Never serialized as `file_url`.
class CertificateImportLocalProof {
  final String localPath;
  final String fileName;
  final String mimeType;
  final int fileSize;

  const CertificateImportLocalProof({
    required this.localPath,
    required this.fileName,
    required this.mimeType,
    required this.fileSize,
  });
}

/// Presign ticket for direct R2 upload.
class CertificateImportPresignTicket {
  final String fileId;
  final String uploadUrl;
  final int expiresIn;
  final Map<String, String> requiredHeaders;

  const CertificateImportPresignTicket({
    required this.fileId,
    required this.uploadUrl,
    required this.expiresIn,
    this.requiredHeaders = const {},
  });
}

/// Legacy remote file metadata. Do not put `image.path` / `file.path` in [url].
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

  bool get isRemoteUrl {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return uri.hasScheme &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }

  Map<String, dynamic> toJson() {
    if (!isRemoteUrl) {
      throw StateError(
        'CertificateImportFilePayload.url must be a remote https URL, not a local path',
      );
    }
    return {
      'file_url': url,
      'file_name': name,
      'file_type': type,
      if (ocrRawText != null) 'ocr_raw_text': ocrRawText,
    };
  }
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

  /// Only a consistency check for class rows; the API does not store it.
  final int? clubTypeId;

  /// Instructor of a honor row (the API treats the two as exclusive). Both
  /// null leaves it as is; [clearInstructor] removes it. Never set on classes.
  final String? instructorUserId;
  final String? instructorName;
  final bool clearInstructor;

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
    this.clubTypeId,
    this.instructorUserId,
    this.instructorName,
    this.clearInstructor = false,
  });

  /// Body for saving [item]. [previous] is the row before the edit: the
  /// instructor only goes out when it changed, so an unchanged one is not
  /// checked again (and cannot block an unrelated edit if that person stopped
  /// being eligible). Classes never send one.
  factory CertificateImportItemUpdatePayload.fromItem(
    CertificateImportItem item, {
    CertificateImportItem? previous,
  }) {
    final isHonor = item.type == CertificateImportItemType.honor;
    final instructor = isHonor ? item.instructor : null;
    final changed = isHonor && instructor != previous?.instructor;
    return CertificateImportItemUpdatePayload(
      itemType: isHonor ? 'HONOR' : 'CLASS',
      honorId: item.honorId,
      classId: item.classId,
      detectedName: item.detectedName,
      completedAt: _apiDate(item.completedAt),
      markAsReady: item.status == CertificateImportItemStatus.ready,
      clubTypeId: item.classRef?.clubTypeId,
      instructorUserId:
          changed && instructor?.isUser == true ? instructor!.userId : null,
      instructorName: changed && instructor != null && !instructor.isUser
          ? instructor.displayName
          : null,
      clearInstructor: changed && instructor == null,
    );
  }

  static String? _apiDate(DateTime? date) {
    if (date == null) return null;
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'item_type': itemType,
        if (honorId != null) 'honor_id': honorId,
        if (classId != null) 'class_id': classId,
        if (classId != null && clubTypeId != null) 'club_type_id': clubTypeId,
        if (detectedName != null) 'detected_name': detectedName,
        if (detectedDate != null) 'detected_date': detectedDate,
        if (completedAt != null) 'completed_at': completedAt,
        if (ocrConfidence != null) 'ocr_confidence': ocrConfidence,
        if (fieldConfidence != null) 'field_confidence': fieldConfidence,
        'mark_as_ready': markAsReady,
        ..._instructorJson(),
      };

  /// `undefined` keeps it, a value sets it (and the API clears the other),
  /// `null` removes it.
  Map<String, dynamic> _instructorJson() {
    if (clearInstructor) {
      return {'instructor_user_id': null, 'instructor_name': null};
    }
    if (instructorUserId != null) {
      return {'instructor_user_id': instructorUserId};
    }
    if (instructorName != null) return {'instructor_name': instructorName};
    return const {};
  }
}
