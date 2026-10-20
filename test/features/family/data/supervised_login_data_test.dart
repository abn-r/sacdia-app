import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/network/interceptors/auth_interceptor.dart';
import 'package:sacdia_app/features/family/data/datasources/family_remote_data_source.dart';
import 'package:sacdia_app/features/family/data/models/dependent_models.dart';
import 'package:sacdia_app/features/family/data/repositories/family_repository_impl.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent_progress_summary.dart';
import 'package:sacdia_app/features/family/domain/entities/supervised_login.dart';
import 'package:sacdia_app/features/family/domain/usecases/enable_supervised_login.dart';

import '../family_fixtures.dart';

class _Recording implements HttpClientAdapter {
  _Recording(this.status, this.body);

  final int status;
  final Object body;
  final requests = <RequestOptions>[];

  RequestOptions get last => requests.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? _,
    Future<void>? __,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

FamilyRemoteDataSourceImpl _ds(_Recording adapter) =>
    FamilyRemoteDataSourceImpl(
      dio: Dio(BaseOptions(baseUrl: 'http://localhost:3000'))
        ..httpClientAdapter = adapter,
      baseUrl: 'http://localhost:3000',
    );

Map<String, Object?> _loginJson({
  String method = 'handle',
  String? handle = 'ana-7kq4m9',
  Object? disabledAt,
  String? disabledReason,
}) =>
    {
      'method': method,
      'login_handle': handle,
      'email': null,
      'origin': 'guardian_enabled',
      'enabled_at': '2026-10-19T10:00:00.000Z',
      'disabled_at': disabledAt,
      'disabled_reason': disabledReason,
      'password_set_by': 'guardian',
    };

void main() {
  group('DependentSummary: access fields', () {
    test('parses access_mode, supervised_login, devices and milestone', () {
      final s = FamilyJson.summary(
        dependentJson(
          age: 14,
          accessMode: 'supervised_login',
          supervisedLogin: {
            'method': 'handle',
            'login_handle': 'ana-7kq4m9',
            'enabled_at': '2026-10-19T10:00:00.000Z',
            'disabled_at': null,
          },
          ageMilestoneReached: true,
          linkedDevices: 0,
        ),
      );

      expect(s.accessMode, AccessMode.supervisedLogin);
      expect(s.supervisedLogin!.method, SupervisedLoginMethod.handle);
      expect(s.supervisedLogin!.loginHandle, 'ana-7kq4m9');
      expect(s.supervisedLogin!.isDisabled, isFalse);
      expect(s.hasActiveOwnLogin, isTrue);
      expect(s.ageMilestoneReached, isTrue);
    });

    test('a payload from before 3a stays guardian-managed (safe defaults)', () {
      final json = dependentJson()
        ..remove('access_mode')
        ..remove('supervised_login')
        ..remove('linked_devices_count')
        ..remove('age_milestone_reached');
      final s = FamilyJson.summary(json);

      expect(s.accessMode, AccessMode.guardianManaged);
      expect(s.supervisedLogin, isNull);
      expect(s.linkedDevicesCount, 0);
      expect(s.ageMilestoneReached, isFalse);
      expect(s.hasActiveOwnLogin, isFalse);
    });

    test('a disabled login is not an active own login', () {
      final s = FamilyJson.summary(
        dependentJson(
          accessMode: 'guardian_managed',
          supervisedLogin: {
            'method': 'handle',
            'login_handle': 'ana-7kq4m9',
            'disabled_at': '2026-10-19T10:00:00.000Z',
            'disabled_reason': 'guardian',
          },
        ),
      );
      expect(s.hasActiveOwnLogin, isFalse);
      expect(s.supervisedLogin!.isDisabled, isTrue);
      expect(s.supervisedLogin!.canBeReactivated, isTrue);
    });

    test('a login closed by majority or the 90-day purge cannot be reactivated',
        () {
      for (final reason in ['age_majority', 'unlinked_purged']) {
        final info = FamilyJson.supervisedLoginInfo(
          _loginJson(
              disabledAt: '2026-10-19T10:00:00.000Z', disabledReason: reason),
        );
        expect(info.canBeReactivated, isFalse, reason: reason);
      }
    });

    test('an unknown access_mode is guardian-managed', () {
      expect(AccessMode.parse('hologram'), AccessMode.guardianManaged);
      expect(AccessMode.parse(null), AccessMode.guardianManaged);
    });
  });

  group('outcome', () {
    test('parses pending_guardian', () {
      expect(
        DependentOutcome.parse('pending_guardian'),
        DependentOutcome.pendingGuardian,
      );
      expect(DependentOutcome.parse('other_guardian'),
          DependentOutcome.otherGuardian);
      expect(DependentOutcome.parse('???'), DependentOutcome.frozen);
    });
  });

  group('GET supervised-login', () {
    test('parses eligibility, reason and the login', () {
      final status = FamilyJson.supervisedLoginStatus({
        'eligible': false,
        'ineligible_reason': 'consent_not_verified',
        'supervised_login': null,
      });
      expect(status.eligible, isFalse);
      expect(status.ineligibleReason, IneligibleReason.consentNotVerified);
      expect(status.supervisedLogin, isNull);
    });

    test('without an explicit true there is no eligibility', () {
      expect(FamilyJson.supervisedLoginStatus({}).eligible, isFalse);
      expect(
        FamilyJson.supervisedLoginStatus({'eligible': 'yes'}).eligible,
        isFalse,
      );
    });

    test('an unknown reason is kept as unknown', () {
      expect(IneligibleReason.parse('new_reason'), IneligibleReason.unknown);
      expect(IneligibleReason.parse(null), isNull);
    });

    test('hits the guardian endpoint WITHOUT X-Acting-For', () async {
      final adapter = _Recording(200, {
        'status': 'success',
        'data': {'eligible': true, 'ineligible_reason': null},
      });

      final status = await _ds(adapter).getSupervisedLogin('ana-1');

      expect(adapter.last.method, 'GET');
      expect(
        adapter.last.uri.path,
        '/guardianships/me/dependents/ana-1/supervised-login',
      );
      expect(adapter.last.extra[AuthInterceptor.skipActingForKey], isTrue);
      expect(status.eligible, isTrue);
    });
  });

  group('POST supervised-login (enable)', () {
    final okBody = {
      'status': 'success',
      'data': {
        'supervised_login': _loginJson(),
        'devices_revoked': 1,
      },
    };

    test('handle: method + password only, no email', () async {
      final adapter = _Recording(201, okBody);

      final result = await _ds(adapter).enableSupervisedLogin(
        dependentId: 'ana-1',
        method: SupervisedLoginMethod.handle,
        password: 'Password123',
      );

      expect(adapter.last.method, 'POST');
      expect(
        adapter.last.uri.path,
        '/guardianships/me/dependents/ana-1/supervised-login',
      );
      expect(
          adapter.last.data, {'method': 'handle', 'password': 'Password123'});
      expect(adapter.last.extra[AuthInterceptor.skipActingForKey], isTrue);
      expect(result.supervisedLogin.loginHandle, 'ana-7kq4m9');
      expect(result.devicesRevoked, 1);
    });

    test('email: method + email + password', () async {
      final adapter = _Recording(201, okBody);

      await _ds(adapter).enableSupervisedLogin(
        dependentId: 'ana-1',
        method: SupervisedLoginMethod.email,
        email: 'ana@example.com',
        password: 'Password123',
      );

      expect(adapter.last.data, {
        'method': 'email',
        'email': 'ana@example.com',
        'password': 'Password123',
      });
    });

    test('the params never print the password', () {
      const params = EnableSupervisedLoginParams(
        dependentId: 'ana-1',
        method: SupervisedLoginMethod.handle,
        password: 'Password123',
      );
      expect(params.props, isNot(contains('Password123')));
      expect(params.toString(), isNot(contains('Password123')));
    });

    test('keeps the business code of a refusal', () async {
      final adapter = _Recording(409, {
        'status': 'error',
        'code': 'SUPERVISED_LOGIN_EMAIL_UNAVAILABLE',
        'message': 'RAW',
        'details': {'x': 1},
      });

      await expectLater(
        _ds(adapter).enableSupervisedLogin(
          dependentId: 'ana-1',
          method: SupervisedLoginMethod.email,
          email: 'a@b.co',
          password: 'Password123',
        ),
        throwsA(
          isA<ServerException>().having(
            (e) => e.errorCode,
            'errorCode',
            'SUPERVISED_LOGIN_EMAIL_UNAVAILABLE',
          ),
        ),
      );
    });

    test('a 201 without the login block is a failure, not a success', () async {
      final adapter = _Recording(201, {'status': 'success', 'data': {}});

      final repo = FamilyRepositoryImpl(remoteDataSource: _ds(adapter));
      final result = await repo.enableSupervisedLogin(
        dependentId: 'ana-1',
        method: SupervisedLoginMethod.handle,
        password: 'Password123',
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('disable / reactivate / password', () {
    final infoBody = {
      'status': 'success',
      'data': {
        'supervised_login': _loginJson(
          disabledAt: '2026-10-19T10:00:00.000Z',
          disabledReason: 'guardian',
        ),
      },
    };

    test('disable posts an empty body, or the reason when given', () async {
      final adapter = _Recording(200, infoBody);
      final ds = _ds(adapter);

      final info = await ds.disableSupervisedLogin(dependentId: 'ana-1');
      expect(
          adapter.last.uri.path, endsWith('/ana-1/supervised-login/disable'));
      expect(adapter.last.data, <String, dynamic>{});
      expect(info.isDisabled, isTrue);

      await ds.disableSupervisedLogin(dependentId: 'ana-1', reason: 'castigo');
      expect(adapter.last.data, {'reason': 'castigo'});
      expect(adapter.last.extra[AuthInterceptor.skipActingForKey], isTrue);
    });

    test('reactivate: a handle login sends the NEW password, email sends none',
        () async {
      final adapter = _Recording(200, {
        'status': 'success',
        'data': {'supervised_login': _loginJson()},
      });
      final ds = _ds(adapter);

      await ds.reactivateSupervisedLogin(
        dependentId: 'ana-1',
        password: 'NewPassword9',
      );
      expect(
        adapter.last.uri.path,
        endsWith('/ana-1/supervised-login/reactivate'),
      );
      expect(adapter.last.data, {'password': 'NewPassword9'});

      await ds.reactivateSupervisedLogin(dependentId: 'ana-1');
      expect(adapter.last.data, <String, dynamic>{});
    });

    test('password reset: the guardian-set password, or none for email',
        () async {
      final adapter = _Recording(200, {
        'status': 'success',
        'data': {'sessions_revoked': 2},
      });
      final ds = _ds(adapter);

      final result = await ds.resetSupervisedPassword(
        dependentId: 'ana-1',
        password: 'NewPassword9',
      );
      expect(
          adapter.last.uri.path, endsWith('/ana-1/supervised-login/password'));
      expect(adapter.last.data, {'password': 'NewPassword9'});
      expect(result.sessionsRevoked, 2);

      await ds.resetSupervisedPassword(dependentId: 'ana-1');
      expect(adapter.last.data, <String, dynamic>{});
    });
  });

  group('GET summary: strict allowlist', () {
    test('reads only classes, honors counts and attendance', () {
      final summary = FamilyJson.progressSummary({
        'dependent': {
          'user_id': 'ana-1',
          'name': 'Ana',
          'age': 14,
          'access_mode': 'supervised_login',
          // Nada de esto debe llegar a la pantalla:
          'email': 'ana@example.com',
          'login_handle': 'ana-7kq4m9',
          'allergies': ['maní'],
        },
        'classes': [
          {
            'class_id': 3,
            'name': 'Amigo',
            'progress_percent': 62,
            'sections_completed': 5,
            'sections_total': 8,
            'notes': 'nota privada del consejero',
          },
        ],
        'honors': {'completed': 3, 'in_progress': 2},
        'attendance': {
          'from': '2026-01-01',
          'to': '2026-10-19',
          'activities_total': 12,
          'activities_attended': 9,
        },
        'dues': null,
        'health': {
          'diseases': ['asma']
        },
        'emergency_contacts': [
          {'name': 'Madre', 'phone': '555'},
        ],
        'generated_at': '2026-10-19T12:00:00.000Z',
      });

      expect(summary.userId, 'ana-1');
      expect(summary.age, 14);
      expect(summary.supervisedLogin, isTrue);
      expect(summary.classes.single.name, 'Amigo');
      expect(summary.classes.single.progressPercent, 62);
      expect(summary.classes.single.sectionsCompleted, 5);
      expect(summary.classes.single.sectionsTotal, 8);
      expect(summary.honorsCompleted, 3);
      expect(summary.honorsInProgress, 2);
      expect(summary.attendance.activitiesAttended, 9);
      expect(summary.attendance.percent, 75);

      // Todo lo que el modelo guarda, en una sola cadena: ni salud ni contacto
      // ni notas ni el usuario del menor.
      final dump = '${summary.props}${summary.classes.map((c) => c.props)}';
      for (final leak in [
        'maní',
        'asma',
        'nota privada',
        '555',
        'ana@example.com',
        'ana-7kq4m9',
      ]) {
        expect(dump, isNot(contains(leak)), reason: leak);
      }
    });

    test('tolerates an empty payload', () {
      final summary = FamilyJson.progressSummary({});
      expect(summary.classes, isEmpty);
      expect(summary.attendance.percent, 0);
      expect(summary.honorsCompleted, 0);
    });

    test('progress is clamped to 0..100', () {
      final summary = FamilyJson.progressSummary({
        'classes': [
          {'name': 'A', 'progress_percent': 150},
          {'name': 'B', 'progress_percent': -4},
        ],
      });
      expect(summary.classes.map((c) => c.progressPercent), [100, 0]);
    });

    test('hits the summary endpoint WITHOUT X-Acting-For', () async {
      final adapter = _Recording(200, {'status': 'success', 'data': {}});

      await _ds(adapter).getProgressSummary('ana-1');

      expect(
          adapter.last.uri.path, '/guardianships/me/dependents/ana-1/summary');
      expect(adapter.last.extra[AuthInterceptor.skipActingForKey], isTrue);
    });

    test('a pending guardian gets a 409 with its code', () async {
      final repo = FamilyRepositoryImpl(
        remoteDataSource: _ds(_Recording(409, {
          'status': 'error',
          'code': 'GUARDIANSHIP_CONSENT_NOT_VERIFIED',
          'message': 'x',
        })),
      );

      final result = await repo.getProgressSummary('ana-1');

      final failure = result.fold((f) => f, (_) => null);
      expect(failure, isA<ServerFailure>());
      expect(failure!.errorCode, 'GUARDIANSHIP_CONSENT_NOT_VERIFIED');
    });
  });

  test('attendance percent rounds and never exceeds 100', () {
    expect(
      const AttendanceSummary(activitiesTotal: 3, activitiesAttended: 2)
          .percent,
      67,
    );
    expect(
      const AttendanceSummary(activitiesTotal: 2, activitiesAttended: 5)
          .percent,
      100,
    );
  });
}
