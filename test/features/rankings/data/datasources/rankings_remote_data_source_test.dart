import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/data/datasources/rankings_remote_data_source.dart';

void main() {
  group('RankingsRemoteDataSourceImpl.getClubRankings', () {
    test('requests annual folder club rankings with institutional filters',
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
                  'data': [
                    {
                      'rank_position': 1,
                      'club_name': 'Club Alfa',
                      'club_enrollment_id': 'enrollment-1',
                      'ecclesiastical_year_id': 1,
                      'local_field_id': 10,
                      'total_earned_points': 85,
                      'total_max_points': 100,
                      'progress_percentage': 85,
                      'award_category_name': 'Club Oro',
                      'folder_score_pct': 90,
                      'finance_score_pct': 80,
                      'camporee_score_pct': 70,
                      'evidence_score_pct': 100,
                      'composite_score_pct': 85.5,
                      'composite_calculated_at': '2026-05-28T12:00:00.000Z',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final dataSource = RankingsRemoteDataSourceImpl(
        dio: dio,
        baseUrl: 'https://api.test/api/v1',
      );

      final rankings = await dataSource.getClubRankings(
        clubTypeId: 2,
        yearId: 1,
        localFieldId: 10,
      );

      expect(captured.path, 'https://api.test/api/v1/annual-folders/rankings');
      expect(captured.queryParameters, containsPair('club_type_id', 2));
      expect(captured.queryParameters, containsPair('year_id', 1));
      expect(captured.queryParameters, containsPair('local_field_id', 10));
      expect(rankings, hasLength(1));
      expect(rankings.first.clubName, 'Club Alfa');
      expect(rankings.first.compositeScorePct, 85.5);
      expect(rankings.first.awardCategoryName, 'Club Oro');
    });
  });
}
