import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/consent/consent_error_messages.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/errors/failures.dart';

ConsentEvidenceLocalFile _file(
  String name, {
  String? mime,
  int size = 1024,
}) =>
    ConsentEvidenceLocalFile(
      path: '/tmp/$name',
      name: name,
      mimeType: mime ?? ConsentEvidenceLocalFile.mimeFromName(name),
      sizeBytes: size,
    );

void main() {
  group('ConsentEvidenceLocalFile.problem', () {
    test('accepts JPEG, PNG, WebP and PDF within 10 MB', () {
      for (final name in ['a.jpg', 'a.JPEG', 'a.png', 'a.webp', 'a.pdf']) {
        expect(_file(name).problem, isNull, reason: name);
      }
      expect(
        _file('a.pdf', size: consentEvidenceMaxBytes).problem,
        isNull,
        reason: 'exactly 10 MB is allowed',
      );
    });

    test('rejects an 11 MB file before any network call', () {
      expect(
        _file('a.jpg', size: consentEvidenceMaxBytes + 1).problem,
        ConsentFileProblem.tooLarge,
      );
    });

    test('rejects HEIC and HEIF with its own problem', () {
      expect(_file('a.heic').problem, ConsentFileProblem.heic);
      expect(_file('a.HEIF').problem, ConsentFileProblem.heic);
    });

    test('rejects other types and empty files', () {
      expect(_file('a.gif').problem, ConsentFileProblem.unsupportedType);
      expect(_file('a.exe').problem, ConsentFileProblem.unsupportedType);
      expect(_file('noext').problem, ConsentFileProblem.unsupportedType);
      expect(_file('a.pdf', size: 0).problem, ConsentFileProblem.empty);
    });

    test('isPdf and isImage follow the MIME type', () {
      expect(_file('a.pdf').isPdf, isTrue);
      expect(_file('a.pdf').isImage, isFalse);
      expect(_file('a.png').isImage, isTrue);
    });
  });

  test('toFormData sends one multipart field "file" with name and type',
      () async {
    final dir = Directory.systemTemp.createTempSync('consent_form_data');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/ficha.pdf';
    File(path).writeAsBytesSync([37, 80, 68, 70]);

    final data = await ConsentEvidenceLocalFile(
      path: path,
      name: 'ficha.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 4,
    ).toFormData();

    expect(data.files, hasLength(1));
    expect(data.files.single.key, 'file');
    expect(data.files.single.value.filename, 'ficha.pdf');
    expect(data.files.single.value.contentType?.mimeType, 'application/pdf');
    expect(data.fields, isEmpty);
  });

  group('ConsentEvidenceJson', () {
    test('parses the upload receipt', () {
      final receipt = ConsentEvidenceJson.receipt({
        'evidence_id': 'ev-1',
        'content_type': 'image/jpeg',
        'size_bytes': 123456,
        'uploaded_at': '2026-10-19T12:00:00.000Z',
      });
      expect(receipt.evidenceId, 'ev-1');
      expect(receipt.contentType, 'image/jpeg');
      expect(receipt.sizeBytes, 123456);
      expect(receipt.uploadedAt, DateTime.utc(2026, 10, 19, 12));
    });

    test('parses the signed access (director adds who uploaded)', () {
      final access = ConsentEvidenceJson.access({
        'url': 'https://signed.example.com/x.pdf?sig=abc',
        'expires_in': 900,
        'content_type': 'application/pdf',
        'uploaded_at': '2026-10-19T12:00:00.000Z',
        'uploaded_by_display_name': 'Laura Díaz',
      });
      expect(access.isPdf, isTrue);
      expect(access.isImage, isFalse);
      expect(access.expiresIn, 900);
      expect(access.uploadedByDisplayName, 'Laura Díaz');
    });

    test('a guardian access has no uploader name', () {
      final access = ConsentEvidenceJson.access({
        'url': 'https://signed.example.com/x.jpg',
        'expires_in': 900,
        'content_type': 'image/jpeg',
      });
      expect(access.isImage, isTrue);
      expect(access.uploadedByDisplayName, isNull);
      expect(access.uploadedAt, isNull);
    });
  });

  group('ConsentEvidencePicker', () {
    test('camera and gallery return a re-encoded image with its MIME',
        () async {
      final sources = <ImageSource>[];
      final picker = ConsentEvidencePicker(
        pickImage: (source) async {
          sources.add(source);
          return XFile.fromData(
            Uint8List.fromList([1, 2, 3]),
            name: 'photo.jpg',
            path: '/tmp/photo.jpg',
          );
        },
      );

      final camera = await picker.pick(ConsentSource.camera);
      final gallery = await picker.pick(ConsentSource.gallery);

      expect(sources, [ImageSource.camera, ImageSource.gallery]);
      expect(camera?.mimeType, 'image/jpeg');
      expect(camera?.problem, isNull);
      expect(gallery?.name, 'photo.jpg');
    });

    test('a HEIC that slips through is flagged and never uploadable', () async {
      final picker = ConsentEvidencePicker(
        pickImage: (_) async => XFile.fromData(
          Uint8List.fromList([1]),
          name: 'IMG_0001.HEIC',
          path: '/tmp/IMG_0001.HEIC',
        ),
      );
      final picked = await picker.pick(ConsentSource.gallery);
      expect(picked?.problem, ConsentFileProblem.heic);
    });

    test('the PDF picker returns an application/pdf file', () async {
      final picker = ConsentEvidencePicker(
        pickPdf: () async =>
            (path: '/tmp/ficha.pdf', name: 'ficha.pdf', size: 2048),
      );
      final picked = await picker.pick(ConsentSource.pdf);
      expect(picked?.isPdf, isTrue);
      expect(picked?.sizeBytes, 2048);
    });

    test('cancelling returns null', () async {
      final picker = ConsentEvidencePicker(
        pickImage: (_) async => null,
        pickPdf: () async => null,
      );
      expect(await picker.pick(ConsentSource.camera), isNull);
      expect(await picker.pick(ConsentSource.pdf), isNull);
    });
  });

  group('consent error keys', () {
    test('every 2c code maps to errors.<code lowercase>', () {
      for (final code in [
        'GUARDIANSHIP_EVIDENCE_NOT_FOUND',
        'GUARDIANSHIP_EVIDENCE_REQUIRED',
        'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
        'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY',
        'MR_CONSENT_CONFIRMATION_REQUIRED',
        'MR_CONSENT_NOT_VERIFIED',
      ]) {
        expect(consentErrorKey(code), 'errors.${code.toLowerCase()}');
      }
    });

    test('every consent code has an errors.* translation in all 4 locales', () {
      for (final locale in ['es', 'en', 'fr', 'pt-BR']) {
        final json = jsonDecode(
          File('assets/translations/$locale.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final errors = json['errors'] as Map<String, dynamic>;
        for (final code in consentErrorCodes) {
          expect(
            errors[code.toLowerCase()],
            isA<String>(),
            reason: 'errors.${code.toLowerCase()} missing in $locale',
          );
        }
      }
    });

    test('unknown or missing codes have no key', () {
      expect(consentErrorKey(null), isNull);
      expect(consentErrorKey('SOMETHING_ELSE'), isNull);
    });

    test('predicates read only the business code', () {
      const unavailable = ServerFailure(
        message: 'x',
        code: 503,
        errorCode: 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
      );
      const notFound = ServerFailure(
        message: 'x',
        code: 404,
        errorCode: 'GUARDIANSHIP_EVIDENCE_NOT_FOUND',
      );
      const fourEyes = AuthFailure(
        message: 'x',
        code: 403,
        errorCode: 'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY',
      );
      expect(isConsentEvidenceUnavailable(unavailable), isTrue);
      expect(isConsentEvidenceUnavailable(notFound), isFalse);
      expect(isConsentEvidenceNotFound(notFound), isTrue);
      expect(isCustodianSelfVerify(fourEyes), isTrue);
      expect(isCustodianSelfVerify(unavailable), isFalse);
      expect(isConsentEvidenceUnavailable('boom'), isFalse);
    });
  });
}
