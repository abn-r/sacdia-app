import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/coordinator/data/datasources/coordinator_remote_data_source.dart';

CoordinatorRemoteDataSourceImpl _dataSourceReturning(Object body) {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object>(
            requestOptions: options,
            statusCode: 200,
            data: body,
          ),
        );
      },
    ),
  );
  return CoordinatorRemoteDataSourceImpl(
    dio: dio,
    baseUrl: 'https://api.test/api/v1',
  );
}

void main() {
  group('CoordinatorRemoteDataSourceImpl.getSlaDashboard', () {
    test('unwraps the { status, data } envelope', () async {
      final dataSource = _dataSourceReturning(const {
        'status': 'ok',
        'data': {
          'investiture': {'total_pending': 2},
          'validation': {
            'class_sections_pending': 3,
            'honors_pending': 3,
            'total_pending': 6,
          },
        },
      });

      final result = await dataSource.getSlaDashboard();

      expect(result.evidence.pending, 6);
      expect(result.investiture.pending, 2);
    });

    test('still accepts an unwrapped payload', () async {
      final dataSource = _dataSourceReturning(const {
        'validation': {'total_pending': 4},
      });

      final result = await dataSource.getSlaDashboard();

      expect(result.evidence.pending, 4);
    });
  });
}
