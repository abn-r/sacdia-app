import 'package:sacdia_app/core/widgets/instructor_selection.dart';

/// Business codes the certificate import flow knows how to classify.
///
/// The backend codes come back in `message` or `code` (legacy BadRequest
/// envelopes). The synthetic ones ([network], [timeout]) are produced by the
/// data layer when no HTTP response exists.
abstract final class CertificateImportErrorCode {
  static const pdfTooManyPages = 'CERTIFICATE_IMPORT_PDF_TOO_MANY_PAGES';
  static const pdfEncrypted = 'CERTIFICATE_IMPORT_PDF_ENCRYPTED';
  static const pdfInvalid = 'CERTIFICATE_IMPORT_PDF_INVALID';
  static const pdfBusy = 'CERTIFICATE_IMPORT_PDF_BUSY';
  static const ocrUnavailable = 'CERTIFICATE_IMPORT_OCR_UNAVAILABLE';
  static const ocrQuota = 'CERTIFICATE_IMPORT_OCR_QUOTA';
  static const ocrFailed = 'CERTIFICATE_IMPORT_OCR_FAILED';
  static const ocrUnsupportedType = 'CERTIFICATE_IMPORT_OCR_UNSUPPORTED_TYPE';
  static const ocrFileTooLarge = 'CERTIFICATE_IMPORT_OCR_FILE_TOO_LARGE';
  static const fileNotConfirmed = 'CERTIFICATE_IMPORT_FILE_NOT_CONFIRMED';
  static const dateTooOld = 'CERTIFICATE_IMPORT_DATE_TOO_OLD';
  static const dateInFuture = 'CERTIFICATE_IMPORT_DATE_IN_FUTURE';
  static const dateInvalid = 'CERTIFICATE_IMPORT_DATE_INVALID';
  static const classClubTypeMismatch =
      'CERTIFICATE_IMPORT_CLASS_CLUB_TYPE_MISMATCH';
  static const honorInstructorNotAllowed =
      'CERTIFICATE_IMPORT_HONOR_INSTRUCTOR_NOT_ALLOWED';
  static const batchNotDeletable = 'CERTIFICATE_IMPORT_BATCH_NOT_DELETABLE';
  static const ocrInProgress = 'CERTIFICATE_IMPORT_OCR_IN_PROGRESS';

  /// No HTTP response: no connectivity, DNS or TLS failure.
  static const network = 'NETWORK';

  /// No HTTP response: connect, send or receive timed out.
  static const timeout = 'TIMEOUT';

  static const Set<String> all = {
    pdfTooManyPages,
    pdfEncrypted,
    pdfInvalid,
    pdfBusy,
    ocrUnavailable,
    ocrQuota,
    ocrFailed,
    ocrUnsupportedType,
    ocrFileTooLarge,
    fileNotConfirmed,
    dateTooOld,
    dateInFuture,
    dateInvalid,
    classClubTypeMismatch,
    honorInstructorNotAllowed,
    ...InstructorErrorCode.all,
    batchNotDeletable,
    ocrInProgress,
    network,
    timeout,
  };

  /// Returns [value] only when it is a code this flow understands.
  static String? known(Object? value) =>
      value is String && all.contains(value) ? value : null;
}
