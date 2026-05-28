import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/classes/data/datasources/classes_remote_data_source.dart';

void main() {
  group('ClassesRemoteDataSourceImpl', () {
    test('passes enrollmentId as query param when fetching progress detail',
        () async {
      late RequestOptions captured;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const {
                  'class_id': 13,
                  'class_name': 'Guía',
                  'club_type_id': 2,
                  'enrollment_id': 901,
                  'modules': <dynamic>[],
                },
              ),
            );
          },
        ),
      );

      final dataSource = ClassesRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      await dataSource.getClassWithProgress(
        '104a2549-2056-4b9b-aaeb-51d8fd43191d',
        13,
        enrollmentId: 901,
      );

      expect(captured.path,
          'https://api.test/api/v1/users/104a2549-2056-4b9b-aaeb-51d8fd43191d/classes/13/progress');
      expect(captured.queryParameters, containsPair('enrollmentId', 901));
    });
  });
}
