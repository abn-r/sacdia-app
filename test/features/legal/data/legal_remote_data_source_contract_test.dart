import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/legal/data/datasources/legal_remote_data_source.dart';
import 'package:sacdia_app/features/legal/data/repositories/legal_repository_impl.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';

import '../../../support/http_adapters.dart';

const _baseUrl = 'http://localhost:3000/api/v1';

({LegalRemoteDataSourceImpl ds, JsonAdapter adapter}) _build(
  int status,
  Object body,
) {
  final adapter = JsonAdapter(status, body);
  final dio = Dio()..httpClientAdapter = adapter;
  return (
    ds: LegalRemoteDataSourceImpl(dio: dio, baseUrl: _baseUrl),
    adapter: adapter,
  );
}

Map<String, dynamic> _statusEnvelope({bool pending = true}) => {
      'status': 'success',
      'data': {
        'requires_acceptance': pending,
        'documents': [
          {
            'document_type': 'terms',
            'version': '1.0.0-store',
            'url': 'https://sacdia.com/terms',
            'accepted': !pending,
            'accepted_at': pending ? null : '2026-10-15T22:01:00.000Z',
          },
          {
            'document_type': 'privacy',
            'version': '1.0.0-store',
            'url': 'https://sacdia.com/privacy',
            'accepted': true,
            'accepted_at': '2026-10-15T22:01:00.000Z',
          },
        ],
      },
    };

Map<String, dynamic> _mismatchError() => {
      'status': 'error',
      'statusCode': 400,
      'code': 'LEGAL_VERSION_MISMATCH',
      'message': 'Los documentos legales se actualizaron.',
      'timestamp': '2026-10-15T22:01:00.000Z',
      'path': '/api/v1/users/me/legal-acceptance',
    };

void main() {
  group('getCurrentDocuments', () {
    test('GET /legal/current parses data.documents', () async {
      final t = _build(200, {
        'status': 'success',
        'data': {
          'documents': [
            {
              'document_type': 'terms',
              'version': '1.0.0-store',
              'url': 'https://sacdia.com/terms',
            },
            {
              'document_type': 'privacy',
              'version': '1.0.0-store',
              'url': 'https://sacdia.com/privacy',
            },
          ],
        },
      });

      final docs = await t.ds.getCurrentDocuments();

      expect(t.adapter.lastRequest!.method, 'GET');
      expect(t.adapter.lastRequest!.uri.toString(), '$_baseUrl/legal/current');
      expect(docs.map((d) => d.documentType), ['terms', 'privacy']);
      expect(docs.first.version, '1.0.0-store');
      expect(docs.last.url, 'https://sacdia.com/privacy');
    });

    test('throws ServerException when documents is missing', () async {
      final t = _build(200, {
        'status': 'success',
        'data': <String, dynamic>{},
      });
      expect(t.ds.getCurrentDocuments(), throwsA(isA<ServerException>()));
    });
  });

  group('getMyStatus', () {
    test('GET /users/me/legal-acceptance parses LegalStatus', () async {
      final t = _build(200, _statusEnvelope());

      final status = await t.ds.getMyStatus();

      expect(t.adapter.lastRequest!.method, 'GET');
      expect(t.adapter.lastRequest!.uri.toString(),
          '$_baseUrl/users/me/legal-acceptance');
      expect(status.requiresAcceptance, isTrue);
      expect(status.documents, hasLength(2));
      expect(status.documents.first.accepted, isFalse);
      expect(status.documents.first.acceptedAt, isNull);
      expect(
          status.documents.last.acceptedAt, DateTime.utc(2026, 10, 15, 22, 1));
    });
  });

  group('accept', () {
    test('POST sends terms_version/privacy_version and parses LegalStatus',
        () async {
      final t = _build(200, _statusEnvelope(pending: false));

      final status = await t.ds.accept(
        termsVersion: '1.0.0-store',
        privacyVersion: '1.0.0-store',
      );

      final req = t.adapter.lastRequest!;
      expect(req.method, 'POST');
      expect(req.uri.toString(), '$_baseUrl/users/me/legal-acceptance');
      expect(req.data, {
        'terms_version': '1.0.0-store',
        'privacy_version': '1.0.0-store',
      });
      expect(status.requiresAcceptance, isFalse);
    });

    test('400 LEGAL_VERSION_MISMATCH keeps the business errorCode', () async {
      final t = _build(400, _mismatchError());

      await expectLater(
        t.ds.accept(termsVersion: 'old', privacyVersion: 'old'),
        throwsA(
          isA<ServerException>()
              .having((e) => e.errorCode, 'errorCode', 'LEGAL_VERSION_MISMATCH')
              .having((e) => e.code, 'code', 400)
              .having((e) => e.message, 'message',
                  'Los documentos legales se actualizaron.'),
        ),
      );
    });

    test('connection error becomes ConnectionException', () async {
      final dio = Dio()
        ..httpClientAdapter = ErrorAdapter(
          (o) => DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
        );
      final ds = LegalRemoteDataSourceImpl(dio: dio, baseUrl: _baseUrl);

      expect(
        ds.accept(termsVersion: 'a', privacyVersion: 'b'),
        throwsA(isA<ConnectionException>()),
      );
    });
  });

  group('LegalRepositoryImpl', () {
    test('keeps errorCode on the Failure for LEGAL_VERSION_MISMATCH', () async {
      final t = _build(400, _mismatchError());
      final repo = LegalRepositoryImpl(remoteDataSource: t.ds);

      final result =
          await repo.accept(termsVersion: 'old', privacyVersion: 'old');

      final failure = result.fold((f) => f, (_) => null);
      expect(failure, isA<ServerFailure>());
      expect(failure!.errorCode, 'LEGAL_VERSION_MISMATCH');
    });

    test('maps documents to entities and exposes versionOf', () async {
      final t = _build(200, _statusEnvelope());
      final repo = LegalRepositoryImpl(remoteDataSource: t.ds);

      final status = (await repo.getMyStatus()).fold((_) => null, (s) => s)!;

      expect(status.requiresAcceptance, isTrue);
      expect(status.versionOf(LegalDocumentTypes.terms), '1.0.0-store');
      expect(status.versionOf(LegalDocumentTypes.privacy), '1.0.0-store');
      expect(status.versionOf('unknown'), isNull);
    });

    test('malformed body becomes UnexpectedFailure', () async {
      final t = _build(200, {
        'status': 'success',
        'data': {'requires_acceptance': 'yes', 'documents': []},
      });
      final repo = LegalRepositoryImpl(remoteDataSource: t.ds);

      final result = await repo.getMyStatus();

      expect(result.isLeft(), isTrue);
    });
  });
}
