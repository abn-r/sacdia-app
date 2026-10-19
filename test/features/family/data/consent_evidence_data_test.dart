import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/consent/consent_evidence.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/interceptors/acting_error_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/acting_generation_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/features/family/data/datasources/family_remote_data_source.dart';
import 'package:sacdia_app/features/family/data/repositories/family_repository_impl.dart';
import 'package:sacdia_app/features/family/domain/repositories/family_repository.dart';

class _Reply {
  const _Reply(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
}

class _Adapter implements HttpClientAdapter {
  final replies = <String, _Reply>{};
  final sent = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    final reply = replies['${options.method} ${options.uri.path}'] ??
        const _Reply(404, {'status': 'error', 'code': 'NOT_FOUND'});
    return ResponseBody.fromString(
      jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _ok(Object? data) => {'status': 'success', 'data': data};

Map<String, Object?> _err(int status, String code) => {
      'status': 'error',
      'statusCode': status,
      'code': code,
      'message': 'server text',
      'details': {'secret': 'do-not-read'},
    };

const _ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Adapter adapter;
  late ActingForSession session;
  late List<String> forbiddenCalls;
  late FamilyRepository repository;
  late Directory tempDir;
  late ConsentEvidenceLocalFile file;

  const path = '/api/v1/guardianships/me/dependents/ana-1/consent-evidence';

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    adapter = _Adapter();
    session = ActingForSession();
    forbiddenCalls = [];
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
      ..httpClientAdapter = adapter;
    // Mismo orden que DioClient.createDio.
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio, actingForSession: session),
      ActingGenerationInterceptor(session),
      ActingErrorInterceptor(session, onActingForbidden: forbiddenCalls.add),
      ErrorInterceptor(),
    ]);
    repository = FamilyRepositoryImpl(
      remoteDataSource: FamilyRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000/api/v1',
      ),
    );

    tempDir = Directory.systemTemp.createTempSync('family_consent');
    final filePath = '${tempDir.path}/ficha.jpg';
    File(filePath).writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    file = ConsentEvidenceLocalFile(
      path: filePath,
      name: 'ficha.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 3,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Failure failureOf(dynamic either) => (either as dynamic).fold(
        (f) => f as Failure,
        (_) => throw StateError('expected a failure'),
      );

  group('upload', () {
    test('posts the multipart file for that dependent', () async {
      adapter.replies['POST $path'] = _Reply(
        201,
        _ok({
          'evidence_id': 'ev-9',
          'content_type': 'image/jpeg',
          'size_bytes': 3,
          'uploaded_at': '2026-10-19T12:00:00.000Z',
        }),
      );

      final receipt = (await repository.uploadConsentEvidence(
        dependentId: 'ana-1',
        file: file,
      ))
          .getOrElse(() => throw StateError('failed'));

      expect(receipt.evidenceId, 'ev-9');
      final request = adapter.sent.single;
      final form = request.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'ficha.jpg');
      expect(form.files.single.value.contentType?.mimeType, 'image/jpeg');
    });

    test('never sends X-Acting-For, even while acting (skipActingFor)',
        () async {
      session.enter(_ana);
      adapter.replies['POST $path'] = _Reply(
        201,
        _ok({
          'evidence_id': 'ev-9',
          'content_type': 'image/jpeg',
          'size_bytes': 3,
        }),
      );
      adapter.replies['GET $path'] = _Reply(
        200,
        _ok({
          'url': 'https://signed.example.com/x.jpg',
          'expires_in': 900,
          'content_type': 'image/jpeg',
        }),
      );

      await repository.uploadConsentEvidence(dependentId: 'ana-1', file: file);
      await repository.getConsentEvidence('ana-1');

      expect(adapter.sent, hasLength(2));
      for (final request in adapter.sent) {
        expect(request.headers.containsKey('X-Acting-For'), isFalse,
            reason: '${request.method} ${request.uri.path}');
        expect(request.extra[AuthInterceptor.skipActingForKey], isTrue);
      }
    });

    test('keeps the business code of every upload error', () async {
      const cases = <(int, String)>[
        (400, 'FILE_TYPE_INVALID'),
        (400, 'FILE_REQUIRED'),
        (400, 'FILE_TOO_LARGE'),
        (404, 'GUARDIANSHIP_NOT_FOUND'),
        (503, 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE'),
      ];
      for (final (status, code) in cases) {
        adapter.replies['POST $path'] = _Reply(status, _err(status, code));

        final failure = failureOf(await repository.uploadConsentEvidence(
          dependentId: 'ana-1',
          file: file,
        ));

        expect(failure.code, status, reason: code);
        expect(failure.errorCode, code);
      }
    });

    test('409 keeps the already-verified code', () async {
      adapter.replies['POST $path'] =
          _Reply(409, _err(409, 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED'));

      final failure = failureOf(await repository.uploadConsentEvidence(
        dependentId: 'ana-1',
        file: file,
      ));

      expect(failure.code, 409);
      expect(failure.errorCode, 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED');
    });

    test('429 (20 uploads per hour) keeps the HTTP status', () async {
      adapter.replies['POST $path'] = const _Reply(
        429,
        {'status': 'error', 'message': 'ThrottlerException'},
      );

      final failure = failureOf(await repository.uploadConsentEvidence(
        dependentId: 'ana-1',
        file: file,
      ));

      expect(failure.code, 429);
    });

    test(
        'a 403 ACTING_FOR_SCOPE_DENIED while acting is surfaced for that '
        'action and does not exit acting', () async {
      session.enter(_ana);
      adapter.replies['POST $path'] =
          _Reply(403, _err(403, 'ACTING_FOR_SCOPE_DENIED'));

      final failure = failureOf(await repository.uploadConsentEvidence(
        dependentId: 'ana-1',
        file: file,
      ));

      expect(failure, isA<AuthFailure>());
      expect(failure.errorCode, 'ACTING_FOR_SCOPE_DENIED');
      expect(forbiddenCalls, isEmpty);
      expect(session.isActing, isTrue);
    });
  });

  group('read', () {
    test('returns the signed URL without an uploader name', () async {
      adapter.replies['GET $path'] = _Reply(
        200,
        _ok({
          'url': 'https://signed.example.com/x.pdf?sig=1',
          'expires_in': 900,
          'content_type': 'application/pdf',
          'uploaded_at': '2026-10-19T12:00:00.000Z',
        }),
      );

      final access = (await repository.getConsentEvidence('ana-1'))
          .getOrElse(() => throw StateError('failed'));

      expect(access.isPdf, isTrue);
      expect(access.expiresIn, 900);
      expect(access.uploadedByDisplayName, isNull);
    });

    test('404 GUARDIANSHIP_EVIDENCE_NOT_FOUND vs GUARDIANSHIP_NOT_FOUND',
        () async {
      adapter.replies['GET $path'] =
          _Reply(404, _err(404, 'GUARDIANSHIP_EVIDENCE_NOT_FOUND'));
      expect(
        failureOf(await repository.getConsentEvidence('ana-1')).errorCode,
        'GUARDIANSHIP_EVIDENCE_NOT_FOUND',
      );

      adapter.replies['GET $path'] =
          _Reply(404, _err(404, 'GUARDIANSHIP_NOT_FOUND'));
      expect(
        failureOf(await repository.getConsentEvidence('ana-1')).errorCode,
        'GUARDIANSHIP_NOT_FOUND',
      );
    });
  });
}
