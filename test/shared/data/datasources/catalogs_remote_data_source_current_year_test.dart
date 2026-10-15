import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/shared/data/datasources/catalogs_remote_data_source.dart';

/// The backend ignores `?active=` on GET /catalogs/ecclesiastical-years and
/// returns every year newest first, so taking the first item picked a future
/// year. The current year must come from /ecclesiastical-years/current.
void main() {
  test('getCurrentEcclesiasticalYear reads the /current endpoint', () async {
    final requested = <String>[];
    final dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requested.add(options.path);
          final isCurrent = options.path.endsWith('/current');
          handler.resolve(
            Response<Object>(
              requestOptions: options,
              statusCode: 200,
              data: isCurrent
                  ? const {
                      'ecclesiastical_year_id': 1,
                      'name': '2026',
                      'start_date': '2026-01-01',
                      'end_date': '2026-12-31',
                      'active': true,
                    }
                  : const [
                      {
                        'ecclesiastical_year_id': 2,
                        'name': '2027',
                        'start_date': '2027-01-01',
                        'end_date': '2027-12-31',
                        'active': false,
                      },
                      {
                        'ecclesiastical_year_id': 1,
                        'name': '2026',
                        'start_date': '2026-01-01',
                        'end_date': '2026-12-31',
                        'active': true,
                      },
                    ],
            ),
          );
        },
      ),
    );

    final dataSource = CatalogsRemoteDataSourceImpl(
      dio: dio,
      baseUrl: 'https://api.test/api/v1',
    );

    final year = await dataSource.getCurrentEcclesiasticalYear();

    expect(year?.ecclesiasticalYearId, 1);
    expect(year?.active, isTrue);
    expect(
      requested.single,
      'https://api.test/api/v1/catalogs/ecclesiastical-years/current',
    );
  });
}
