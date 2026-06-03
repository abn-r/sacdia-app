import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/profile/data/datasources/profile_remote_data_source.dart';

void main() {
  group('ProfileRemoteDataSourceImpl.updateUserProfile', () {
    test('unwraps API data envelope and preserves user id after PATCH',
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
                  'status': 'success',
                  'data': {
                    'user_id': '104a2549-2056-4b9b-aaeb-51d8fd43191d',
                    'email': 'member@sacdia.test',
                    'name': 'Miembro',
                    'blood': 'O+',
                  },
                },
              ),
            );
          },
        ),
      );

      final dataSource = ProfileRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await dataSource.updateUserProfile(
        '104a2549-2056-4b9b-aaeb-51d8fd43191d',
        {'blood': 'O+'},
      );

      expect(
        captured.path,
        'https://api.test/api/v1/users/104a2549-2056-4b9b-aaeb-51d8fd43191d',
      );
      expect(captured.data, {'blood': 'O+'});
      expect(result.id, '104a2549-2056-4b9b-aaeb-51d8fd43191d');
      expect(result.blood, 'O+');
    });
  });
}
