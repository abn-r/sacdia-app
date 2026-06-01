import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/honors/data/datasources/honors_remote_data_source.dart';

void main() {
  group('HonorsRemoteDataSourceImpl.updateRequirementProgress', () {
    test(
        'uses live users/:userId/honors/:honorId/requirements/:requirementId/progress endpoint',
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
                    'requirement_id': 10,
                    'requirement_number': 1,
                    'requirement_text': 'Texto requisito',
                    'completed': true,
                    'has_sub_items': false,
                    'notes': 'ok',
                  },
                },
              ),
            );
          },
        ),
      );

      final ds = HonorsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final result = await ds.updateRequirementProgress(
        userId: 'user-1',
        honorId: 7,
        requirementId: 10,
        completed: true,
        notes: 'ok',
      );

      expect(
        captured.path,
        'https://api.test/api/v1/users/user-1/honors/7/requirements/10/progress',
      );
      expect(captured.data, {'completed': true, 'notes': 'ok'});
      expect(result.requirementId, 10);
      expect(result.completed, isTrue);
    });
  });
}
