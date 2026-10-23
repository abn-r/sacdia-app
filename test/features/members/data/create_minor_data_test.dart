import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/core/network/network_info.dart';
import 'package:sacdia_app/features/members/data/datasources/members_remote_data_source.dart';
import 'package:sacdia_app/features/members/data/repositories/members_repository_impl.dart';
import 'package:sacdia_app/features/members/domain/entities/create_minor.dart';
import 'package:sacdia_app/features/members/domain/repositories/members_repository.dart';

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
      // El backend lo omite en producción: el cliente no debe leerlo.
      'details': {'secret': 'do-not-read'},
    };

class _Online implements NetworkInfo {
  @override
  Future<bool> get isConnected async => true;
}

const _created = {
  'dependent': {
    'user_id': 'a1b2c3d4-0000-4000-8000-000000000001',
    'name': 'Luis',
    'birthday': '2016-02-10',
    'age': 10,
  },
  'guardianship': {
    'guardianship_id': 'gs-9',
    'is_custodian': true,
    'consent_status': 'pending',
  },
  'assignment': {
    'assignment_id': 'req-9',
    'status': 'pending',
    'club_section_id': 12,
  },
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Adapter adapter;
  late MembersRepository repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    adapter = _Adapter();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
      ..httpClientAdapter = adapter;
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio),
      ErrorInterceptor(),
    ]);
    repository = MembersRepositoryImpl(
      remoteDataSource: MembersRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000/api/v1',
      ),
      networkInfo: _Online(),
    );
  });

  Failure failureOf(dynamic either) => (either as dynamic)
      .fold((f) => f as Failure, (_) => throw StateError('ok'));

  const input = CreateMinorInput(
    clubSectionId: 12,
    name: 'Luis',
    paternalLastName: 'Pérez',
    maternalLastName: 'López',
    birthday: '2016-02-10',
    gender: 'M',
    swornDeclaration: true,
    acceptedTermsVersion: '2.0.0-family',
    acceptedPrivacyVersion: '2.0.0-family',
  );

  group('create minor', () {
    test('posts the exact body to the section and parses the result', () async {
      adapter.replies['POST /api/v1/club-sections/12/dependents'] =
          _Reply(201, _ok(_created));

      final result = (await repository.createMinor(input))
          .getOrElse(() => throw StateError('failed'));

      final request = adapter.sent.single;
      expect(request.data, {
        'name': 'Luis',
        'paternal_last_name': 'Pérez',
        'maternal_last_name': 'López',
        'birthday': '2016-02-10',
        'gender': 'M',
        'sworn_declaration': true,
        'accepted_terms_version': '2.0.0-family',
        'accepted_privacy_version': '2.0.0-family',
      });
      expect(result.userId, 'a1b2c3d4-0000-4000-8000-000000000001');
      expect(result.name, 'Luis');
      expect(result.age, 10);
      expect(result.guardianshipId, 'gs-9');
      expect(result.assignmentId, 'req-9');
      expect(result.clubSectionId, 12);
      expect(result.consentPending, isTrue);
    });

    test('optional fields are left out and never an email or account key',
        () async {
      adapter.replies['POST /api/v1/club-sections/12/dependents'] =
          _Reply(201, _ok(_created));

      await repository.createMinor(const CreateMinorInput(
        clubSectionId: 12,
        name: 'Luis',
        paternalLastName: 'Pérez',
        birthday: '2016-02-10',
        swornDeclaration: true,
        acceptedTermsVersion: '2.0.0-family',
        acceptedPrivacyVersion: '2.0.0-family',
      ));

      final body = adapter.sent.single.data as Map;
      expect(body.containsKey('maternal_last_name'), isFalse);
      expect(body.containsKey('gender'), isFalse);
      expect(body.containsKey('email'), isFalse);
      expect(body.containsKey('access_mode'), isFalse);
      expect(body.containsKey('account'), isFalse);
    });

    test('every business error keeps its code and never reads details',
        () async {
      const cases = <(int, String)>[
        (400, 'LEGAL_VERSION_MISMATCH'),
        (403, 'GUARD_PERMISSION_DENIED'),
        (404, 'FAMILY_FEATURE_DISABLED'),
        (422, 'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE'),
        (500, 'POST_REG_NO_ACTIVE_YEAR'),
      ];
      for (final (status, code) in cases) {
        adapter.replies['POST /api/v1/club-sections/12/dependents'] =
            _Reply(status, _err(status, code));

        final failure = failureOf(await repository.createMinor(input));

        expect(failure.errorCode, code, reason: '$status $code');
        expect(failure.code, status);
      }
    });
  });

  group('claim code', () {
    const path = '/api/v1/club-sections/12/dependents/ana-1/claim-codes';

    test('posts to the section dependent and parses code and expiry', () async {
      adapter.replies['POST $path'] = _Reply(
        201,
        _ok({'code': '7KQ4-M9TX', 'expires_at': '2026-10-27T10:00:00.000Z'}),
      );

      final issued = (await repository.issueClaimCode(
        clubSectionId: 12,
        dependentUserId: 'ana-1',
      ))
          .getOrElse(() => throw StateError('failed'));

      expect(issued.code, '7KQ4-M9TX');
      expect(issued.expiresAt.toUtc(), DateTime.utc(2026, 10, 27, 10));
    });

    test('errors keep their code; a code-less 429 keeps the status', () async {
      adapter.replies['POST $path'] =
          _Reply(409, _err(409, 'GUARDIANSHIP_ALREADY_GUARDIAN'));
      expect(
        failureOf(await repository.issueClaimCode(
          clubSectionId: 12,
          dependentUserId: 'ana-1',
        ))
            .errorCode,
        'GUARDIANSHIP_ALREADY_GUARDIAN',
      );

      adapter.replies['POST $path'] =
          const _Reply(429, {'status': 'error', 'message': 'slow down'});
      final limited = failureOf(await repository.issueClaimCode(
        clubSectionId: 12,
        dependentUserId: 'ana-1',
      ));
      expect(limited.code, 429);
      expect(limited.errorCode, isNull);
    });
  });
}
