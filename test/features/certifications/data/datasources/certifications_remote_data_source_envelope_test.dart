import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/certifications/data/datasources/certifications_remote_data_source.dart';

/// GET list/detail/user wrap `{ status: 'success', data: ... }`.
/// Casting `response.data as List` throws Map-is-not-List.
void main() {
  const baseUrl = 'https://api.test/api/v1';

  CertificationsRemoteDataSourceImpl buildDataSource(dynamic responseData) {
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: 200,
              data: responseData,
            ),
          );
        },
      ),
    );
    return CertificationsRemoteDataSourceImpl(dio: dio, baseUrl: baseUrl);
  }

  test('getCertifications unwraps paginated { data: [...] } envelope',
      () async {
    final dataSource = buildDataSource({
      'status': 'success',
      'data': [
        {
          'certification_id': 1,
          'name': 'Guía Mayor',
          'description': 'Cert',
          'active': true,
          'modules_count': 3,
        },
      ],
      'meta': {'page': 1, 'limit': 50, 'total': 1},
    });

    final result = await dataSource.getCertifications();

    expect(result, hasLength(1));
    expect(result.first.certificationId, 1);
    expect(result.first.name, 'Guía Mayor');
    expect(result.first.modulesCount, 3);
  });

  test('getUserCertifications unwraps { data: [...] } envelope', () async {
    final dataSource = buildDataSource({
      'status': 'success',
      'data': [
        {
          'enrollment_id': 10,
          'certification_id': 1,
          'certification': {'name': 'Guía Mayor'},
          'enrollment_date': '2026-01-15T00:00:00.000Z',
          'completion_status': 'in_progress',
          'progress_percentage': 40,
          'modules_completed': 1,
          'modules_total': 3,
          'active': true,
        },
      ],
    });

    final result = await dataSource.getUserCertifications('user-1');

    expect(result, hasLength(1));
    expect(result.first.enrollmentId, 10);
    expect(result.first.certificationName, 'Guía Mayor');
  });

  test('getCertificationDetail unwraps { data: { ... } } envelope', () async {
    final dataSource = buildDataSource({
      'status': 'success',
      'data': {
        'certification_id': 1,
        'name': 'Guía Mayor',
        'description': 'Cert',
        'active': true,
        'modules': [
          {
            'module_id': 2,
            'name': 'Módulo',
            'sections': [
              {'section_id': 3, 'name': 'Sección'},
            ],
          },
        ],
      },
    });

    final result = await dataSource.getCertificationDetail(1);

    expect(result.certificationId, 1);
    expect(result.name, 'Guía Mayor');
    expect(result.modules, hasLength(1));
    expect(result.modules.first.sections, hasLength(1));
  });
}
