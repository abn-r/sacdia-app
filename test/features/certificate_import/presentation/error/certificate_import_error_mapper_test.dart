import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/certificate_import/presentation/error/certificate_import_error_mapper.dart';

CertificateImportErrorKind _kind(Object? error) =>
    CertificateImportErrorMapper.map(error).kind;

void main() {
  // Without EasyLocalization initialised, tr() returns the key, so the copy
  // assertions below check which key each error resolves to.
  group('CertificateImportErrorMapper', () {
    const byCode = <String, CertificateImportErrorKind>{
      'CERTIFICATE_IMPORT_PDF_TOO_MANY_PAGES':
          CertificateImportErrorKind.pdfTooManyPages,
      'CERTIFICATE_IMPORT_PDF_ENCRYPTED':
          CertificateImportErrorKind.pdfEncrypted,
      'CERTIFICATE_IMPORT_PDF_INVALID': CertificateImportErrorKind.pdfInvalid,
      'CERTIFICATE_IMPORT_PDF_BUSY': CertificateImportErrorKind.pdfBusy,
      'CERTIFICATE_IMPORT_OCR_UNAVAILABLE':
          CertificateImportErrorKind.ocrUnavailable,
      'CERTIFICATE_IMPORT_OCR_QUOTA': CertificateImportErrorKind.ocrQuota,
      'CERTIFICATE_IMPORT_OCR_FAILED': CertificateImportErrorKind.ocrFailed,
      'CERTIFICATE_IMPORT_OCR_UNSUPPORTED_TYPE':
          CertificateImportErrorKind.ocrUnsupportedType,
      'CERTIFICATE_IMPORT_OCR_FILE_TOO_LARGE':
          CertificateImportErrorKind.ocrFileTooLarge,
      'CERTIFICATE_IMPORT_FILE_NOT_CONFIRMED':
          CertificateImportErrorKind.fileNotConfirmed,
      'NETWORK': CertificateImportErrorKind.offline,
      'TIMEOUT': CertificateImportErrorKind.timeout,
    };

    for (final entry in byCode.entries) {
      test('maps ${entry.key} from errorCode', () {
        final info = CertificateImportErrorMapper.map(
          ServerFailure(message: 'backend text', errorCode: entry.key),
        );
        expect(info.kind, entry.value);
        expect(info.title, startsWith('certificate_import.errors.'));
        expect(info.body, isNot(contains(entry.key)));
      });

      test('maps ${entry.key} from the legacy message envelope', () {
        expect(
            _kind(ServerFailure(message: entry.key, code: 400)), entry.value);
      });
    }

    test('PDF_BUSY (HTTP 429) is retryable and keeps the busy copy', () {
      final info = CertificateImportErrorMapper.map(
        const ServerFailure(message: 'x', code: 429),
      );
      expect(info.kind, CertificateImportErrorKind.pdfBusy);
      expect(info.action, CertificateImportErrorAction.retry);
      expect(info.title, 'certificate_import.errors.pdf_busy.title');
    });

    test('PDF problems ask for another file, OCR ones need no action', () {
      expect(
        CertificateImportErrorMapper.map(const ServerFailure(
          message: 'x',
          errorCode: 'CERTIFICATE_IMPORT_PDF_ENCRYPTED',
        )).action,
        CertificateImportErrorAction.chooseOtherFile,
      );
      expect(
        CertificateImportErrorMapper.map(const ServerFailure(
          message: 'x',
          errorCode: 'CERTIFICATE_IMPORT_OCR_FAILED',
        )).action,
        CertificateImportErrorAction.none,
      );
    });

    test('network and timeout sources', () {
      final request = RequestOptions(path: '/x');
      expect(_kind(const ConnectionFailure(message: 'x')),
          CertificateImportErrorKind.offline);
      expect(_kind(const NetworkFailure(message: 'x')),
          CertificateImportErrorKind.offline);
      expect(_kind(const SocketException('down')),
          CertificateImportErrorKind.offline);
      expect(
          _kind(TimeoutException('slow')), CertificateImportErrorKind.timeout);
      expect(
        _kind(DioException(
          requestOptions: request,
          type: DioExceptionType.connectionError,
        )),
        CertificateImportErrorKind.offline,
      );
      expect(
        _kind(DioException(
          requestOptions: request,
          type: DioExceptionType.receiveTimeout,
        )),
        CertificateImportErrorKind.timeout,
      );
    });

    test('upload context says the file is still there', () {
      final info = CertificateImportErrorMapper.map(
        const ServerFailure(message: 'x', errorCode: 'NETWORK'),
        context: CertificateImportErrorContext.upload,
      );
      expect(info.body, 'certificate_import.errors.offline_upload.body');
      expect(info.title, 'certificate_import.errors.offline.title');
    });

    test('unknown errors never leak their text', () {
      for (final error in <Object>[
        const ServerFailure(message: 'ECONNRESET at /srv/app.ts:9', code: 500),
        const UnexpectedFailure(message: 'type Null is not a subtype'),
        Exception('boom'),
        'plain string',
      ]) {
        final info = CertificateImportErrorMapper.map(error);
        expect(info.kind, CertificateImportErrorKind.unknown);
        expect(info.body, 'certificate_import.errors.unexpected.body');
        expect(info.body, isNot(contains('boom')));
      }
    });

    test('every copy key exists in all four languages', () {
      final infos = [
        for (final code in byCode.keys)
          for (final context in CertificateImportErrorContext.values)
            CertificateImportErrorMapper.map(
              ServerFailure(message: 'x', errorCode: code),
              context: context,
            ),
        for (final context in CertificateImportErrorContext.values)
          CertificateImportErrorMapper.map(Exception('x'), context: context),
      ];
      final slugs = {
        for (final info in infos) ...[info.title, info.body]
      };
      for (final lang in ['es', 'en', 'fr', 'pt-BR']) {
        final json = jsonDecode(
          File('assets/translations/$lang.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        for (final key in slugs) {
          Object? node = json;
          for (final part in key.split('.')) {
            node = node is Map ? node[part] : null;
          }
          expect(node, isA<String>(), reason: '$key missing in $lang');
        }
      }
    });
  });
}
