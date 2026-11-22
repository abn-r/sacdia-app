import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/certifications/data/datasources/certifications_remote_data_source.dart';
import 'package:sacdia_app/features/certifications/domain/entities/certification_eligibility.dart';

import '../../../../support/l10n_test_support.dart';

/// Contract of the certifications redesign: eligibility, activity options and
/// the business errors of enrolling and leaving.
void main() {
  setUpAll(loadSpanishTranslations);

  const baseUrl = 'https://api.test/api/v1';
  const userId = 'user-1';
  late RequestOptions captured;

  CertificationsRemoteDataSourceImpl buildDataSource({
    Object? data,
    int statusCode = 200,
  }) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          captured = options;
          if (statusCode >= 400) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<dynamic>(
                  requestOptions: options,
                  statusCode: statusCode,
                  data: data,
                ),
              ),
            );
            return;
          }
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: statusCode,
              data: data,
            ),
          );
        },
      ),
    );
    return CertificationsRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
  }

  test('getEligibility reads the enveloped rules', () async {
    final dataSource = buildDataSource(data: const {
      'status': 'success',
      'data': {
        'eligible': false,
        'reason_code': 'CERT_ELIGIBILITY_REQUIRED',
        'rules': [
          {
            'eligibility_rule_id': 4,
            'type': 'MIN_AGE',
            'satisfied': true,
            'reason_code': null,
          },
          {
            'eligibility_rule_id': 5,
            'type': 'BAPTIZED',
            'satisfied': false,
            'reason_code': 'NOT_BAPTIZED',
          },
          {'type': 'SOMETHING_NEW', 'satisfied': false},
        ],
      },
    });

    final result = await dataSource.getEligibility(userId, 7);

    expect(captured.method, 'GET');
    expect(
      captured.path,
      '$baseUrl/certifications/users/$userId/certifications/7/eligibility',
    );
    expect(result.eligible, isFalse);
    expect(result.rules.map((r) => r.type), [
      CertificationEligibilityRuleType.minAge,
      CertificationEligibilityRuleType.baptized,
      CertificationEligibilityRuleType.unknown,
    ]);
    expect(result.rules.map((r) => r.satisfied), [true, false, false]);
    expect(result.rules[1].reasonCode, 'NOT_BAPTIZED');
  });

  test('getEligibility tolerates a missing rules list', () async {
    final dataSource = buildDataSource(data: const {
      'data': {'eligible': true},
    });

    final result = await dataSource.getEligibility(userId, 7);

    expect(result.eligible, isTrue);
    expect(result.rules, isEmpty);
  });

  test('getActivityOptions uses the component route and reads the options',
      () async {
    final dataSource = buildDataSource(data: const {
      'data': [
        {
          'activity_id': 91,
          'name': 'Campamento',
          'activity_date': '2026-03-01T00:00:00.000Z',
          'activity_type_name': 'Campamento',
          'club_name': 'Club Orión',
        },
      ],
    });

    final options = await dataSource.getActivityOptions(userId, 500, 10, 3);

    expect(captured.method, 'GET');
    expect(
      captured.path,
      '$baseUrl/certifications/users/$userId/certification-enrollments/500/'
      'requirements/10/components/3/activity-options',
    );
    expect(options.single.activityId, 91);
    expect(options.single.clubName, 'Club Orión');
    // A date column sent as UTC midnight keeps its calendar day in any zone.
    expect(options.single.activityDate, DateTime(2026, 3, 1));
  });

  for (final entry in {
    'CERT_ELIGIBILITY_REQUIRED': 'Aún no cumples los requisitos',
    'CERT_ALREADY_ENROLLED': 'Ya estás inscrito',
  }.entries) {
    test('enrolling maps ${entry.key} to its own message', () async {
      final dataSource = buildDataSource(
        statusCode: 409,
        data: {'code': entry.key, 'message': 'generic'},
      );

      await expectLater(
        dataSource.enrollCertification(userId, 7),
        throwsA(
          isA<ServerException>().having(
            (e) => e.message,
            'message',
            contains(entry.value),
          ),
        ),
      );
    });
  }

  test('leaving maps CERT_ENROLLMENT_NOT_ABANDONABLE', () async {
    final dataSource = buildDataSource(
      statusCode: 409,
      data: const {
        'code': 'CERT_ENROLLMENT_NOT_ABANDONABLE',
        'message': 'generic',
      },
    );

    await expectLater(
      dataSource.unenrollCertification(userId, 7),
      throwsA(
        isA<ServerException>().having(
          (e) => e.message,
          'message',
          contains('Ya no puedes dejar'),
        ),
      ),
    );
  });
}
