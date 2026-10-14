import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/failures.dart';
import '../../domain/entities/certificate_import_error_code.dart';

/// What went wrong, independent of wording.
enum CertificateImportErrorKind {
  offline,
  timeout,
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

  /// Class row: the historical age gate has nothing to work with.
  dateRequired,
  birthdayRequired,
  classMinimumAgeRequired,

  /// The date falls in no ecclesiastical year, or in more than one.
  yearNotFound,
  ageBelowMinimum,

  /// Resubmit of a row that already left the rejected state.
  itemNotRejected,
  unknown,
}

/// What the user can do about it.
enum CertificateImportErrorAction {
  retry,
  chooseOtherFile,

  /// The member can fix it in their profile (birthday).
  completeProfile,
  none,
}

/// Where the error is shown, to pick the right wording.
enum CertificateImportErrorContext { general, upload }

/// Translated copy for one error. Never carries backend text or codes.
class CertificateImportErrorInfo {
  const CertificateImportErrorInfo._(
    this.kind,
    this.action,
    this._slug, {
    String? bodySlug,
  }) : _bodySlug = bodySlug ?? _slug;

  final CertificateImportErrorKind kind;
  final CertificateImportErrorAction action;
  final String _slug;
  final String _bodySlug;

  String get title => 'certificate_import.errors.$_slug.title'.tr();
  String get body => 'certificate_import.errors.$_bodySlug.body'.tr();
}

/// Turns any failure of the certificate import flow into translated copy.
///
/// Single place that decides what the user reads: views must not print
/// `failure.message`, `error.toString()` or a backend code.
abstract final class CertificateImportErrorMapper {
  static const _retry = CertificateImportErrorAction.retry;
  static const _other = CertificateImportErrorAction.chooseOtherFile;
  static const _none = CertificateImportErrorAction.none;
  static const _profile = CertificateImportErrorAction.completeProfile;

  /// Copy slug and user action per kind.
  static const _specs =
      <CertificateImportErrorKind, (String, CertificateImportErrorAction)>{
    CertificateImportErrorKind.offline: ('offline', _retry),
    CertificateImportErrorKind.timeout: ('timeout', _retry),
    CertificateImportErrorKind.pdfTooManyPages: ('pdf_pages', _other),
    CertificateImportErrorKind.pdfEncrypted: ('pdf_encrypted', _other),
    CertificateImportErrorKind.pdfInvalid: ('pdf_invalid', _other),
    CertificateImportErrorKind.pdfBusy: ('pdf_busy', _retry),
    CertificateImportErrorKind.ocrUnavailable: ('ocr_off', _none),
    CertificateImportErrorKind.ocrQuota: ('ocr_quota', _none),
    CertificateImportErrorKind.ocrFailed: ('ocr_failed', _none),
    CertificateImportErrorKind.ocrUnsupportedType: ('type', _other),
    CertificateImportErrorKind.ocrFileTooLarge: ('too_large', _other),
    CertificateImportErrorKind.fileNotConfirmed: ('not_confirmed', _retry),
    CertificateImportErrorKind.dateTooOld: ('date_old', _none),
    CertificateImportErrorKind.dateInFuture: ('date_future', _none),
    CertificateImportErrorKind.dateInvalid: ('date_invalid', _none),
    CertificateImportErrorKind.classClubTypeMismatch: ('class_mismatch', _none),
    CertificateImportErrorKind.dateRequired: ('age_date_required', _none),
    CertificateImportErrorKind.birthdayRequired: ('age_birthday', _profile),
    CertificateImportErrorKind.classMinimumAgeRequired: (
      'age_class_unset',
      _none,
    ),
    CertificateImportErrorKind.yearNotFound: ('age_year', _none),
    CertificateImportErrorKind.ageBelowMinimum: ('age_below_minimum', _none),
    CertificateImportErrorKind.itemNotRejected: ('item_not_rejected', _none),
    CertificateImportErrorKind.unknown: ('unexpected', _retry),
  };

  /// Kinds whose body changes while uploading ("your file is still here").
  static const _uploadBodies = <CertificateImportErrorKind, String>{
    CertificateImportErrorKind.offline: 'offline_upload',
    CertificateImportErrorKind.unknown: 'unexpected_upload',
  };

  static CertificateImportErrorInfo map(
    Object? error, {
    CertificateImportErrorContext context =
        CertificateImportErrorContext.general,
  }) {
    final kind = kindOf(error);
    final (slug, action) = _specs[kind]!;
    final upload = context == CertificateImportErrorContext.upload;
    return CertificateImportErrorInfo._(
      kind,
      action,
      slug,
      bodySlug: upload ? _uploadBodies[kind] : null,
    );
  }

  /// Copy for a bare business code, such as the batch `ocr_error_code`.
  static CertificateImportErrorInfo mapCode(String? code) => map(
        code == null ? null : ServerFailure(message: '', errorCode: code),
      );

  /// Translated one-liner for snack bars and inline messages.
  static String message(
    Object? error, {
    CertificateImportErrorContext context =
        CertificateImportErrorContext.general,
  }) =>
      map(error, context: context).body;

  static CertificateImportErrorKind kindOf(Object? error) {
    if (error is Failure) {
      final byCode = _byCode(error.errorCode) ?? _byCode(error.message);
      if (byCode != null) return byCode;
      if (error is ConnectionFailure || error is NetworkFailure) {
        return CertificateImportErrorKind.offline;
      }
      // The API only answers 429 for the PDF validation queue.
      if (error.code == 429) return CertificateImportErrorKind.pdfBusy;
      return CertificateImportErrorKind.unknown;
    }
    if (error is SocketException) return CertificateImportErrorKind.offline;
    if (error is TimeoutException) return CertificateImportErrorKind.timeout;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return CertificateImportErrorKind.timeout;
        case DioExceptionType.connectionError:
          return CertificateImportErrorKind.offline;
        default:
          return error.response?.statusCode == 429
              ? CertificateImportErrorKind.pdfBusy
              : CertificateImportErrorKind.unknown;
      }
    }
    return CertificateImportErrorKind.unknown;
  }

  static CertificateImportErrorKind? _byCode(String? code) {
    switch (code) {
      case CertificateImportErrorCode.pdfTooManyPages:
        return CertificateImportErrorKind.pdfTooManyPages;
      case CertificateImportErrorCode.pdfEncrypted:
        return CertificateImportErrorKind.pdfEncrypted;
      case CertificateImportErrorCode.pdfInvalid:
        return CertificateImportErrorKind.pdfInvalid;
      case CertificateImportErrorCode.pdfBusy:
        return CertificateImportErrorKind.pdfBusy;
      case CertificateImportErrorCode.ocrUnavailable:
        return CertificateImportErrorKind.ocrUnavailable;
      case CertificateImportErrorCode.ocrQuota:
        return CertificateImportErrorKind.ocrQuota;
      case CertificateImportErrorCode.ocrFailed:
        return CertificateImportErrorKind.ocrFailed;
      case CertificateImportErrorCode.ocrUnsupportedType:
        return CertificateImportErrorKind.ocrUnsupportedType;
      case CertificateImportErrorCode.ocrFileTooLarge:
        return CertificateImportErrorKind.ocrFileTooLarge;
      case CertificateImportErrorCode.fileNotConfirmed:
        return CertificateImportErrorKind.fileNotConfirmed;
      case CertificateImportErrorCode.dateTooOld:
        return CertificateImportErrorKind.dateTooOld;
      case CertificateImportErrorCode.dateInFuture:
        return CertificateImportErrorKind.dateInFuture;
      case CertificateImportErrorCode.dateInvalid:
        return CertificateImportErrorKind.dateInvalid;
      case CertificateImportErrorCode.classClubTypeMismatch:
        return CertificateImportErrorKind.classClubTypeMismatch;
      case CertificateImportErrorCode.dateRequired:
        return CertificateImportErrorKind.dateRequired;
      case CertificateImportErrorCode.birthdayRequired:
        return CertificateImportErrorKind.birthdayRequired;
      case CertificateImportErrorCode.classMinimumAgeRequired:
        return CertificateImportErrorKind.classMinimumAgeRequired;
      case CertificateImportErrorCode.yearNotFound:
      case CertificateImportErrorCode.yearAmbiguous:
        return CertificateImportErrorKind.yearNotFound;
      case CertificateImportErrorCode.ageBelowMinimum:
        return CertificateImportErrorKind.ageBelowMinimum;
      case CertificateImportErrorCode.itemNotRejected:
        return CertificateImportErrorKind.itemNotRejected;
      case CertificateImportErrorCode.network:
        return CertificateImportErrorKind.offline;
      case CertificateImportErrorCode.timeout:
        return CertificateImportErrorKind.timeout;
    }
    return null;
  }
}
