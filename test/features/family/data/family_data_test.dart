import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/constants/app_constants.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/core/network/interceptors/error_interceptor.dart';
import 'package:sacdia_app/features/family/data/datasources/family_remote_data_source.dart';
import 'package:sacdia_app/features/family/data/repositories/family_repository_impl.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/repositories/family_repository.dart';

import '../family_fixtures.dart';

class _Reply {
  const _Reply(this.status, this.body);
  final int status;
  final Map<String, Object?> body;
}

/// Responde por "METODO ruta" y guarda lo que recibió.
class _Adapter implements HttpClientAdapter {
  final replies = <String, _Reply>{};
  final sent = <RequestOptions>[];
  final bodies = <String, Object?>{};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    sent.add(options);
    bodies['${options.method} ${options.uri.path}'] = options.data;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _Adapter adapter;
  late ActingForSession session;
  late FamilyRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      AppConstants.tokenKey: 'access-token',
    });
    adapter = _Adapter();
    session = ActingForSession();
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
      ..httpClientAdapter = adapter;
    // Cadena real: si algo olvidara el opt-out, el encabezado saldría.
    dio.interceptors.addAll([
      AuthInterceptor(dio: dio, actingForSession: session),
      ErrorInterceptor(),
    ]);
    repository = FamilyRepositoryImpl(
      remoteDataSource: FamilyRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000/api/v1',
      ),
    );
  });

  const root = '/api/v1/guardianships';

  group('parsing', () {
    test('list maps dependents, limit and consent', () async {
      adapter.replies['GET $root/me/dependents'] = _Reply(
        200,
        _ok({
          'dependents': [
            dependentJson(),
            dependentJson(
              id: 'luis-1',
              name: 'Luis',
              consent: 'verified',
              club: clubPending,
            ),
          ],
          'limits': {'max_dependents': 10},
        }),
      );

      final overview = (await repository.listDependents()).getOrElse(
        () => throw StateError('failed'),
      );

      expect(overview.maxDependents, 10);
      expect(overview.dependents.map((d) => d.userId), ['ana-1', 'luis-1']);
      final ana = overview.dependents.first;
      expect(ana.firstName, 'Ana');
      expect(ana.fullName, 'Ana Pérez López');
      expect(ana.age, 9);
      expect(ana.guardianship.consentStatus, GuardianConsentStatus.pending);
      expect(ana.clubMembership, isNull);
      final luis = overview.dependents.last;
      expect(luis.guardianship.isVerified, isTrue);
      expect(luis.guardianship.verifiedAt, isNotNull);
      expect(luis.clubMembership?.isPending, isTrue);
      expect(luis.clubMembership?.clubName, 'Club Águilas');
      expect(overview.canAddMore, isTrue);
    });

    test('canAddMore turns false at the limit', () {
      final full = FamilyOverview(
        dependents: List.generate(10, (i) => summary(id: 'd$i')),
        maxDependents: 10,
      );
      expect(full.canAddMore, isFalse);
    });

    test('actable excludes frozen dependents', () {
      final overview = FamilyOverview(
        dependents: [summary(), summary(id: 'luis-1', frozen: true)],
        maxDependents: 10,
      );
      expect(overview.actable.map((d) => d.userId), ['ana-1']);
    });

    test('detail maps guardians and a missing relationship does not crash',
        () async {
      adapter.replies['GET $root/me/dependents/ana-1'] = _Reply(
        200,
        _ok(detailJson(guardians: [
          guardianJson(),
          guardianJson(
            id: 'gs-2',
            userId: 'guardian-2',
            name: 'Pedro',
            primary: false,
            me: false,
            consent: 'verified',
          ),
        ])),
      );

      final detail = (await repository.getDependent('ana-1')).getOrElse(
        () => throw StateError('failed'),
      );

      expect(detail.guardians, hasLength(2));
      expect(detail.guardians.first.isMe, isTrue);
      expect(detail.otherGuardians.single.displayName, 'Pedro');
    });

    test('an unknown consent status is treated as pending', () {
      expect(
          GuardianConsentStatus.parse('weird'), GuardianConsentStatus.pending);
      expect(GuardianConsentStatus.parse(null), GuardianConsentStatus.pending);
    });

    test('deletion impact maps outcomes', () async {
      adapter.replies['GET $root/me/deletion-impact'] = _Reply(
        200,
        _ok({
          'dependents': [
            {
              'user_id': 'ana-1',
              'display_name': 'Ana Pérez',
              'outcome': 'club_custody',
            },
            {
              'user_id': 'luis-1',
              'display_name': 'Luis Pérez',
              'outcome': 'frozen',
            },
          ],
        }),
      );

      final impact = (await repository.deletionImpact()).getOrElse(
        () => throw StateError('failed'),
      );

      expect(impact.map((e) => e.outcome), [
        DependentOutcome.clubCustody,
        DependentOutcome.frozen,
      ]);
    });
  });

  group('requests', () {
    test('every call skips X-Acting-For, even while acting', () async {
      session.enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      adapter.replies['GET $root/me/dependents'] = _Reply(
        200,
        _ok({
          'dependents': [],
          'limits': {'max_dependents': 10}
        }),
      );
      adapter.replies['GET $root/me/dependents/ana-1'] =
          _Reply(200, _ok(detailJson()));
      adapter.replies['POST $root/me/dependents'] =
          _Reply(201, _ok(dependentJson()));
      adapter.replies['POST $root/me/dependents/ana-1/link-codes'] = _Reply(
        201,
        _ok({'code': '7KQ4-M9TX', 'expires_at': '2026-10-22T10:00:00.000Z'}),
      );
      adapter.replies['POST $root/link-codes/redeem'] =
          _Reply(201, _ok(dependentJson()));
      adapter.replies['POST $root/gs-1/revoke'] = _Reply(
        200,
        _ok({
          'guardianship_id': 'gs-1',
          'consent_status': 'revoked',
          'dependent_outcome': 'frozen',
        }),
      );
      adapter.replies['GET $root/me/deletion-impact'] =
          _Reply(200, _ok({'dependents': []}));

      await repository.listDependents();
      await repository.getDependent('ana-1');
      await repository.createDependent(const CreateDependentInput(
        name: 'Ana',
        paternalLastName: 'Pérez',
        birthday: '2017-04-02',
        relationshipTypeId: 'rel-1',
        swornDeclaration: true,
        acceptedTermsVersion: '1.0.0',
        acceptedPrivacyVersion: '1.0.0',
      ));
      await repository.issueLinkCode('ana-1');
      await repository.redeemLinkCode(
        code: 'abcd-efgh',
        relationshipTypeId: 'rel-1',
        swornDeclaration: true,
      );
      await repository.revoke(guardianshipId: 'gs-1', removedByPrimary: false);
      await repository.deletionImpact();

      expect(adapter.sent, hasLength(7));
      for (final request in adapter.sent) {
        expect(
          request.headers.containsKey(AuthInterceptor.actingForHeader),
          isFalse,
          reason: '${request.method} ${request.uri.path}',
        );
        expect(request.extra[AuthInterceptor.skipActingForKey], isTrue);
      }
    });

    test('create sends the contract body (maternal last name optional)',
        () async {
      adapter.replies['POST $root/me/dependents'] =
          _Reply(201, _ok(dependentJson()));

      await repository.createDependent(const CreateDependentInput(
        name: 'Ana',
        paternalLastName: 'Pérez',
        birthday: '2017-04-02',
        relationshipTypeId: 'rel-1',
        swornDeclaration: true,
        acceptedTermsVersion: '1.0.0-store',
        acceptedPrivacyVersion: '1.0.1-store',
      ));

      expect(adapter.bodies['POST $root/me/dependents'], {
        'name': 'Ana',
        'paternal_last_name': 'Pérez',
        'birthday': '2017-04-02',
        'relationship_type_id': 'rel-1',
        'sworn_declaration': true,
        'accepted_terms_version': '1.0.0-store',
        'accepted_privacy_version': '1.0.1-store',
      });
    });

    test('redeem sends the code untouched (any case; server normalizes)',
        () async {
      adapter.replies['POST $root/link-codes/redeem'] =
          _Reply(201, _ok(dependentJson()));

      await repository.redeemLinkCode(
        code: '7kq4-m9tx',
        relationshipTypeId: 'rel-1',
        swornDeclaration: true,
      );

      final body = adapter.bodies['POST $root/link-codes/redeem'] as Map;
      expect(body['code'], '7kq4-m9tx');
      expect(body['sworn_declaration'], isTrue);
    });

    test('issue code asks for a second guardian', () async {
      adapter.replies['POST $root/me/dependents/ana-1/link-codes'] = _Reply(
        201,
        _ok({'code': '7KQ4-M9TX', 'expires_at': '2026-10-22T10:00:00.000Z'}),
      );

      final code = (await repository.issueLinkCode('ana-1')).getOrElse(
        () => throw StateError('failed'),
      );

      expect(code.code, '7KQ4-M9TX');
      expect(
        adapter.bodies['POST $root/me/dependents/ana-1/link-codes'],
        {'purpose': 'second_guardian'},
      );
    });

    test('revoke maps leave vs primary removal reasons and the outcome',
        () async {
      adapter.replies['POST $root/gs-1/revoke'] = _Reply(
        200,
        _ok({
          'guardianship_id': 'gs-1',
          'consent_status': 'revoked',
          'dependent_outcome': 'other_guardian',
        }),
      );

      final left = await repository.revoke(
        guardianshipId: 'gs-1',
        removedByPrimary: false,
      );
      expect(adapter.bodies['POST $root/gs-1/revoke'], {
        'reason': 'guardian_left',
      });
      expect(
        left.getOrElse(() => throw StateError('failed')).outcome,
        DependentOutcome.otherGuardian,
      );

      await repository.revoke(guardianshipId: 'gs-1', removedByPrimary: true);
      expect(adapter.bodies['POST $root/gs-1/revoke'], {
        'reason': 'removed_by_primary',
      });
    });
  });

  group('relationship types', () {
    late FamilyRemoteDataSourceImpl dataSource;

    setUp(() {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
        ..httpClientAdapter = adapter;
      dio.interceptors.add(ErrorInterceptor());
      dataSource = FamilyRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000/api/v1',
      );
    });

    test('reads GET /guardianships/relationship-types in server order',
        () async {
      adapter.replies['GET $root/relationship-types'] = _Reply(
        200,
        _ok([
          {'relationship_type_id': 'uuid-a', 'name': 'Padre'},
          {'relationship_type_id': 'uuid-b', 'name': 'Madre'},
          {'relationship_type_id': 'uuid-c', 'name': 'Otro'},
        ]),
      );

      final types = await dataSource.getRelationshipTypes();

      expect(adapter.sent.single.uri.path, '$root/relationship-types');
      expect(adapter.sent.single.uri.path, isNot(contains('/catalogs')));
      expect(types.map((t) => t.name), ['Padre', 'Madre', 'Otro']);
      expect(types.map((t) => t.id), ['uuid-a', 'uuid-b', 'uuid-c']);
    });

    test('a failure surfaces as an exception, never as a partial list',
        () async {
      adapter.replies['GET $root/relationship-types'] =
          _Reply(500, _err(500, 'INTERNAL'));

      expect(dataSource.getRelationshipTypes(), throwsA(isA<Exception>()));
    });
  });

  group('errors', () {
    test('the business code survives in the Failure, details is never read',
        () async {
      adapter.replies['POST $root/me/dependents'] =
          _Reply(422, _err(422, 'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE'));

      final result =
          await repository.createDependent(const CreateDependentInput(
        name: 'Ana',
        paternalLastName: 'Pérez',
        birthday: '2010-04-02',
        relationshipTypeId: 'rel-1',
        swornDeclaration: true,
        acceptedTermsVersion: '1',
        acceptedPrivacyVersion: '1',
      ));

      final failure = result.swap().getOrElse(() => throw StateError('ok'));
      expect(failure, isA<ServerFailure>());
      expect(failure.errorCode, 'GUARDIANSHIP_DEPENDENT_AGE_OUT_OF_RANGE');
      expect(failure.code, 422);
    });

    test('a 403 keeps its code as an AuthFailure', () async {
      adapter.replies['POST $root/link-codes/redeem'] =
          _Reply(403, _err(403, 'GUARDIANSHIP_LINK_CODE_SELF_REDEEM'));

      final failure = (await repository.redeemLinkCode(
        code: 'x',
        relationshipTypeId: 'rel-1',
        swornDeclaration: true,
      ))
          .swap()
          .getOrElse(() => throw StateError('ok'));

      expect(failure, isA<AuthFailure>());
      expect(failure.errorCode, 'GUARDIANSHIP_LINK_CODE_SELF_REDEEM');
    });

    test('429 and 409 carry their codes', () async {
      adapter.replies['POST $root/link-codes/redeem'] =
          _Reply(429, _err(429, 'GUARDIANSHIP_LINK_CODE_LOCKED'));
      adapter.replies['POST $root/me/dependents/ana-1/link-codes'] =
          _Reply(409, _err(409, 'GUARDIANSHIP_GUARDIAN_LIMIT_REACHED'));

      final locked = await repository.redeemLinkCode(
        code: 'x',
        relationshipTypeId: 'rel-1',
        swornDeclaration: true,
      );
      final limit = await repository.issueLinkCode('ana-1');

      expect(
        locked.swap().getOrElse(() => throw StateError('ok')).errorCode,
        'GUARDIANSHIP_LINK_CODE_LOCKED',
      );
      expect(
        limit.swap().getOrElse(() => throw StateError('ok')).errorCode,
        'GUARDIANSHIP_GUARDIAN_LIMIT_REACHED',
      );
    });

    test('an unwrapped body is a server error, not a crash', () async {
      adapter.replies['GET $root/me/dependents'] =
          const _Reply(200, {'unexpected': true});

      final result = await repository.listDependents();

      expect(result.isLeft(), isTrue);
    });

    test('data source rethrows typed exceptions', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000/api/v1'))
        ..httpClientAdapter = adapter;
      final dataSource = FamilyRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'http://localhost:3000/api/v1',
      );
      adapter.replies['GET $root/me/dependents/zzz'] =
          _Reply(404, _err(404, 'GUARDIANSHIP_NOT_FOUND'));

      await expectLater(
        dataSource.getDependent('zzz'),
        throwsA(
          isA<ServerException>().having(
            (e) => e.errorCode,
            'errorCode',
            'GUARDIANSHIP_NOT_FOUND',
          ),
        ),
      );
    });
  });
}
