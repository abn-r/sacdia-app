import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/units/data/models/scoring_category_model.dart';

void main() {
  group('ScoringCategoryModel', () {
    test('parses scoring_mode from backend payload', () {
      final model = ScoringCategoryModel.fromJson({
        'scoring_category_id': 7,
        'name': 'Biblia',
        'max_points': 10,
        'scoring_mode': 'boolean_full',
        'origin_level': 'LOCAL_FIELD',
        'origin_id': 3,
        'active': true,
        'readonly': false,
      });

      expect(model.scoringMode, 'boolean_full');
      expect(model.isBooleanFull, isTrue);
      expect(model.normalizePoints(5), 10);
      expect(model.normalizePoints(0), 0);
    });

    test('defaults scoring_mode to numeric when backend omits it', () {
      final model = ScoringCategoryModel.fromJson({
        'scoring_category_id': 8,
        'name': 'Participación',
        'max_points': 10,
        'origin_level': 'LOCAL_FIELD',
        'origin_id': 3,
      });

      expect(model.scoringMode, 'numeric');
      expect(model.isBooleanFull, isFalse);
      expect(model.normalizePoints(5), 5);
    });
  });
}
