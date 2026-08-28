import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_score_format.dart';

void main() {
  group('formatCamporeeScoreNumber', () {
    test('drops grouping and trailing zeros', () {
      expect(formatCamporeeScoreNumber(170), '170');
      expect(formatCamporeeScoreNumber(75.5), '75.5');
      expect(formatCamporeeScoreNumber(85), '85');
    });
  });
}
