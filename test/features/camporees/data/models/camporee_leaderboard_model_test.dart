import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/data/models/camporee_leaderboard_model.dart';

void main() {
  group('CamporeeLeaderboardModel', () {
    test('keeps calendar rank and decimal points from ISO payload', () {
      final model = CamporeeLeaderboardModel.fromJson({
        'scope': {'type': 'local', 'camporeeId': 73},
        'rows': [
          {
            'rank': 2,
            'camporee_club_id': 6,
            'club_section_id': 165,
            'club_name': 'Estella',
            'section_name': 'Conquistadores',
            'total_awarded_points': '55.00',
            'total_max_points': '100',
            'percentage': 55,
          },
        ],
      });

      expect(model.scopeType, 'local');
      expect(model.rows.first.rank, 2);
      expect(model.rows.first.totalAwardedPoints, 55);
      expect(model.toEntity().rows.first.clubName, 'Estella');
      // No `visibility` (older server) means the full ranking.
      expect(model.toEntity().isFullRanking, isTrue);
    });

    test('reads the own-sections view without positions', () {
      final entity = CamporeeLeaderboardModel.fromJson({
        'scope': {'type': 'local', 'camporeeId': 73},
        'visibility': 'own',
        'rows': [
          {
            'rank': null,
            'club_section_id': 165,
            'club_name': 'Estella',
            'total_awarded_points': 55,
            'total_max_points': 100,
            'percentage': 55,
          },
        ],
      }).toEntity();

      expect(entity.isFullRanking, isFalse);
      expect(entity.rows.single.rank, isNull);
      expect(entity.rows.single.clubSectionId, 165);
    });
  });
}
