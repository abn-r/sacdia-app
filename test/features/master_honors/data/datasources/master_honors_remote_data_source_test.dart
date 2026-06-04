import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/master_honors/data/datasources/master_honors_remote_data_source.dart';

void main() {
  group('MasterHonorsRemoteDataSourceImpl', () {
    test('uses live users/:userId/master-honors endpoint', () async {
      late RequestOptions captured;

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            captured = options;
            handler.resolve(
              Response<List<dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const [
                  {
                    'user_master_honor_id': 10,
                    'master_honor_id': 2,
                    'name': 'Maestría en Acuática',
                    'master_image': 'https://example.com/a.png',
                    'status': 'REVOKED',
                    'is_current': false,
                    'display_status_label': 'No vigente',
                    'awarded_at': '2026-06-03T10:00:00Z',
                  },
                ],
              ),
            );
          },
        ),
      );

      final dataSource = MasterHonorsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await dataSource.getUserMasterHonors('user-1');

      expect(
          captured.path, 'https://api.test/api/v1/users/user-1/master-honors');
      expect(result, hasLength(1));
      expect(result.single.masterHonorId, 2);
      expect(result.single.displayStatusLabel, 'No vigente');
    });
  });
}
