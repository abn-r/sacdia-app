import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/units/data/models/weekly_record_model.dart';

void main() {
  group('WeeklyRecordModel', () {
    test('parses unit_id and score scoring_mode from backend payload', () {
      final model = WeeklyRecordModel.fromJson({
        'record_id': 11,
        'unit_id': 4,
        'user_id': 'user-1',
        'week': 26,
        'year': 2026,
        'attendance': 0,
        'punctuality': 0,
        'points': 10,
        'active': true,
        'scores': [
          {
            'category_id': 7,
            'category_name': 'Biblia',
            'scoring_mode': 'boolean_full',
            'points': 10,
            'max_points': 10,
          },
        ],
      });

      expect(model.unitId, 4);
      expect(model.scores, hasLength(1));
      expect(model.scores.first.scoringMode, 'boolean_full');
      expect(model.toJson()['unit_id'], 4);
    });

    test('defaults score scoring_mode to numeric when backend omits it', () {
      final model = WeeklyRecordModel.fromJson({
        'record_id': 12,
        'user_id': 'user-2',
        'week': 26,
        'year': 2026,
        'attendance': 0,
        'punctuality': 0,
        'points': 5,
        'active': true,
        'scores': [
          {
            'category_id': 8,
            'category_name': 'Participación',
            'points': 5,
            'max_points': 10,
          },
        ],
      });

      expect(model.unitId, isNull);
      expect(model.scores.first.scoringMode, 'numeric');
    });
  });
}
