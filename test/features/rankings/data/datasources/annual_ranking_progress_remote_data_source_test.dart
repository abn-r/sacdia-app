import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/features/rankings/data/datasources/annual_ranking_progress_remote_data_source.dart';

void main() {
  group('AnnualRankingProgressRemoteDataSourceImpl.getAnnualRankingProgress',
      () {
    test('requests section annual ranking progress endpoint', () async {
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
                data: {
                  'status': 'success',
                  'data': _progressJson(),
                },
              ),
            );
          },
        ),
      );

      final dataSource = AnnualRankingProgressRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final progress = await dataSource.getAnnualRankingProgress(
        sectionId: 2,
        yearId: 1,
      );

      expect(captured.path,
          'https://api.test/api/v1/club-sections/2/annual-ranking-progress');
      expect(captured.queryParameters, containsPair('year_id', 1));
      expect(progress.currentPoints, 7200);
      expect(progress.currentTier?.slug, 'plata');
    });

    test('exposes backend error code when ranking config is missing', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response<Map<String, dynamic>>(
                  requestOptions: options,
                  statusCode: 404,
                  data: {
                    'statusCode': 404,
                    'code': 'ANNUAL_RANKING_CONFIG_NOT_FOUND',
                    'message': 'No existe una configuración anual de ranking',
                  },
                ),
              ),
            );
          },
        ),
      );

      final dataSource = AnnualRankingProgressRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      await expectLater(
        dataSource.getAnnualRankingProgress(sectionId: 2, yearId: 1),
        throwsA(
          isA<ServerException>().having((e) => e.code, 'code', 404).having(
                (e) => e.errorCode,
                'errorCode',
                'ANNUAL_RANKING_CONFIG_NOT_FOUND',
              ),
        ),
      );
    });
  });
}

Map<String, dynamic> _progressJson() => {
      'section_id': 2,
      'club_id': 7,
      'club_name': 'Halcones',
      'club_type': {'club_type_id': 1, 'name': 'Aventureros'},
      'year': {'ecclesiastical_year_id': 1},
      'current_points': 7200,
      'max_points': 10000,
      'progress_percentage': 72,
      'current_tier': {
        'name': 'Plata',
        'slug': 'plata',
        'from_points': 7000,
        'to_points': 8499,
      },
      'next_tier': null,
      'components': const [
        {
          'key': 'annual_folder',
          'label': 'Carpeta anual',
          'earned_points': 4200,
          'max_points': 6000,
          'progress_percentage': 70,
        },
      ],
      'pending_items': const [],
    };
