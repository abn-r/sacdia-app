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
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/members/data/datasources/members_remote_data_source.dart';
import 'package:sacdia_app/features/members/data/repositories/members_repository_impl.dart';
import 'package:sacdia_app/features/members/domain/repositories/members_repository.dart';

class _Reply {
  const _Reply(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
}

/// Responde por "METODO ruta" y guarda lo que recibió.
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
      // El backend lo omite en producción: el cliente no debe leerlo.
      'details': {'secret': 'do-not-read'},
    };

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

const _ana = ActingDependent(userId: 'ana-1', firstName: 'Ana');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Adapter adapter;
  late ActingForSession session;
  late List<String> forbiddenCalls;
  late MembersRepository repository;
  late Directory tempDir;
  late ConsentEvidenceLocalFile file;

  const base = '/api/v1/club-sections/12/membership-requests/req-1';
  const assignmentId = '12/membership-requests/req-1';

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
    repository = MembersRepositoryImpl(
      remoteDataSource: MembersRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000/api/v1',
      ),
      networkInfo: _Online(),
    );

    tempDir = Directory.systemTemp.createTempSync('members_consent');
    final path = '${tempDir.path}/ficha.pdf';
    File(path).writeAsBytesSync([37, 80, 68, 70]);
    file = ConsentEvidenceLocalFile(
      path: path,
      name: 'ficha.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 4,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Failure failureOf<T>(dynamic either) => (either as dynamic)
      .fold((f) => f as Failure, (_) => throw StateError('ok'));

  group('upload', () {
    test('posts one multipart field "file" to the request path', () async {
      adapter.replies['POST $base/consent-evidence'] = _Reply(
        201,
        _ok({
          'evidence_id': 'ev-1',
          'content_type': 'application/pdf',
          'size_bytes': 4,
          'uploaded_at': '2026-10-19T12:00:00.000Z',
        }),
      );

      final result = await repository.uploadConsentEvidence(
        assignmentId: assignmentId,
        file: file,
      );

      final receipt = result.getOrElse(() => throw StateError('failed'));
      expect(receipt.evidenceId, 'ev-1');
      expect(receipt.sizeBytes, 4);
      final request = adapter.sent.single;
      expect(request.data, isA<FormData>());
      final form = request.data as FormData;
      expect(form.files.single.key, 'file');
      expect(form.files.single.value.filename, 'ficha.pdf');
      expect(form.files.single.value.contentType?.mimeType, 'application/pdf');
      expect(request.headers.containsKey('X-Acting-For'), isFalse);
    });

    test('503 keeps the unavailable code (private bucket not configured)',
        () async {
      adapter.replies['POST $base/consent-evidence'] =
          _Reply(503, _err(503, 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE'));

      final failure = failureOf(await repository.uploadConsentEvidence(
        assignmentId: assignmentId,
        file: file,
      ));

      expect(failure, isA<ServerFailure>());
      expect(failure.code, 503);
      expect(failure.errorCode, 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE');
    });

    test('409 keeps the already-verified code (form frozen after verify)',
        () async {
      adapter.replies['POST $base/consent-evidence'] =
          _Reply(409, _err(409, 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED'));

      final failure = failureOf(await repository.uploadConsentEvidence(
        assignmentId: assignmentId,
        file: file,
      ));

      expect(failure, isA<ServerFailure>());
      expect(failure.code, 409);
      expect(failure.errorCode, 'GUARDIANSHIP_CONSENT_ALREADY_VERIFIED');
    });

    test('a 413 without a code keeps the HTTP status', () async {
      adapter.replies['POST $base/consent-evidence'] =
          const _Reply(413, {'status': 'error', 'message': 'too large'});

      final failure = failureOf(await repository.uploadConsentEvidence(
        assignmentId: assignmentId,
        file: file,
      ));

      expect(failure.code, 413);
      expect(failure.errorCode, isNull);
    });
  });

  group('read evidence', () {
    test('parses the signed URL and who uploaded it', () async {
      adapter.replies['GET $base/consent-evidence'] = _Reply(
        200,
        _ok({
          'url': 'https://signed.example.com/x.jpg?sig=1',
          'expires_in': 900,
          'content_type': 'image/jpeg',
          'uploaded_at': '2026-10-19T12:00:00.000Z',
          'uploaded_by_display_name': 'Laura Díaz',
        }),
      );

      final access = (await repository.getConsentEvidence(assignmentId))
          .getOrElse(() => throw StateError('failed'));

      expect(access.url, 'https://signed.example.com/x.jpg?sig=1');
      expect(access.expiresIn, 900);
      expect(access.isImage, isTrue);
      expect(access.uploadedByDisplayName, 'Laura Díaz');
    });

    test('404 and 503 keep their codes', () async {
      adapter.replies['GET $base/consent-evidence'] =
          _Reply(404, _err(404, 'GUARDIANSHIP_EVIDENCE_NOT_FOUND'));
      expect(
        failureOf(await repository.getConsentEvidence(assignmentId)).errorCode,
        'GUARDIANSHIP_EVIDENCE_NOT_FOUND',
      );

      adapter.replies['GET $base/consent-evidence'] =
          _Reply(503, _err(503, 'GUARDIANSHIP_EVIDENCE_UNAVAILABLE'));
      expect(
        failureOf(await repository.getConsentEvidence(assignmentId)).errorCode,
        'GUARDIANSHIP_EVIDENCE_UNAVAILABLE',
      );
    });
  });

  group('verify-consent', () {
    test('sends the confirmation and approve flag', () async {
      adapter.replies['POST $base/verify-consent'] = _Reply(
        200,
        _ok({
          'guardianship': {
            'guardianship_id': 'gs-1',
            'consent_status': 'verified',
            'verified_at': '2026-10-19T12:00:00.000Z',
            'verified_by_user_id': 'director-1',
            'verification_method': 'director_paper_form',
          },
          'assignment': {'assignment_id': 'req-1', 'status': 'active'},
          'approve_error': null,
        }),
      );

      final result = (await repository.verifyConsent(
        assignmentId: assignmentId,
        approve: true,
      ))
          .getOrElse(() => throw StateError('failed'));

      expect(adapter.sent.single.data, {
        'confirm_paper_form_reviewed': true,
        'approve': true,
      });
      expect(result.guardianshipId, 'gs-1');
      expect(result.verifiedByUserId, 'director-1');
      expect(result.verificationMethod, 'director_paper_form');
      expect(result.approved, isTrue);
      expect(result.approvalFailed, isFalse);
    });

    test('approve_error after the commit is reported, not thrown', () async {
      adapter.replies['POST $base/verify-consent'] = _Reply(
        200,
        _ok({
          'guardianship': {
            'guardianship_id': 'gs-1',
            'consent_status': 'verified',
          },
          'assignment': null,
          'approve_error': 'MR_NOT_FOUND',
        }),
      );

      final result = (await repository.verifyConsent(
        assignmentId: assignmentId,
        approve: true,
      ))
          .getOrElse(() => throw StateError('failed'));

      expect(result.approved, isFalse);
      expect(result.approvalFailed, isTrue);
      expect(result.approveError, 'MR_NOT_FOUND');
    });

    test('an already-approved no-op is not a failure', () async {
      adapter.replies['POST $base/verify-consent'] = _Reply(
        200,
        _ok({
          'guardianship': {'guardianship_id': 'gs-1'},
          'assignment': null,
          'approve_error': null,
        }),
      );

      final result = (await repository.verifyConsent(
        assignmentId: assignmentId,
        approve: true,
      ))
          .getOrElse(() => throw StateError('failed'));

      expect(result.approvalFailed, isFalse);
    });

    test('every verify error keeps its business code', () async {
      const cases = <(int, String)>[
        (400, 'MR_CONSENT_CONFIRMATION_REQUIRED'),
        (403, 'GUARDIANSHIP_CUSTODIAN_SELF_VERIFY'),
        (403, 'GUARDIANSHIP_GUARDIAN_SELF_VERIFY'),
        (403, 'GUARD_PERMISSION_DENIED'),
        (404, 'MR_NOT_FOUND'),
        (404, 'GUARDIANSHIP_NOT_FOUND'),
        (409, 'GUARDIANSHIP_EVIDENCE_REQUIRED'),
        (409, 'MR_ALREADY_PENDING'),
      ];
      for (final (status, code) in cases) {
        adapter.replies['POST $base/verify-consent'] =
            _Reply(status, _err(status, code));

        final failure = failureOf(await repository.verifyConsent(
          assignmentId: assignmentId,
          approve: true,
        ));

        expect(failure.code, status, reason: code);
        expect(failure.errorCode, code);
        expect(
          status == 403 ? failure is AuthFailure : failure is ServerFailure,
          isTrue,
          reason: code,
        );
      }
    });
  });

  group('assign club role', () {
    const rolesPath = '/api/v1/clubs/1/sections/2/roles';

    void catalog() {
      adapter.replies['GET /api/v1/catalogs/roles'] = _Reply(
        200,
        _ok([
          {'role_id': 'role-member', 'name': 'member'},
        ]),
      );
    }

    test('409 MR_CONSENT_NOT_VERIFIED keeps its code and status', () async {
      catalog();
      adapter.replies['POST $rolesPath'] =
          _Reply(409, _err(409, 'MR_CONSENT_NOT_VERIFIED'));

      final failure = failureOf(await repository.assignClubRole(
        clubId: 1,
        sectionId: 2,
        userId: 'ana-1',
        role: 'member',
      ));

      expect(failure, isA<ServerFailure>());
      expect(failure.code, 409);
      expect(failure.errorCode, 'MR_CONSENT_NOT_VERIFIED');
    });

    test('a 403 keeps its code too', () async {
      catalog();
      adapter.replies['POST $rolesPath'] =
          _Reply(403, _err(403, 'GUARD_PERMISSION_DENIED'));

      final failure = failureOf(await repository.assignClubRole(
        clubId: 1,
        sectionId: 2,
        userId: 'ana-1',
        role: 'member',
      ));

      expect(failure.code, 403);
      expect(failure.errorCode, 'GUARD_PERMISSION_DENIED');
    });
  });

  group('direct approve of a minor', () {
    test('409 MR_CONSENT_NOT_VERIFIED keeps its code', () async {
      adapter.replies['POST $base/approve'] =
          _Reply(409, _err(409, 'MR_CONSENT_NOT_VERIFIED'));

      final failure = failureOf(await repository.approveJoinRequest(
        assignmentId,
      ));

      expect(failure.code, 409);
      expect(failure.errorCode, 'MR_CONSENT_NOT_VERIFIED');
    });
  });

  group('acting', () {
    test(
        'ACTING_FOR_SCOPE_DENIED is reported as an action error and does not '
        'exit acting', () async {
      session.enter(_ana);
      adapter.replies['POST $base/verify-consent'] =
          _Reply(403, _err(403, 'ACTING_FOR_SCOPE_DENIED'));

      final failure = failureOf(await repository.verifyConsent(
        assignmentId: assignmentId,
        approve: true,
      ));

      expect(failure.errorCode, 'ACTING_FOR_SCOPE_DENIED');
      expect(forbiddenCalls, isEmpty);
      expect(session.isActing, isTrue);
    });
  });
}
