import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/rankings/presentation/utils/ranking_status_labels.dart';

void main() {
  group('ranking status labels', () {
    test('uses i18n key for raw investiture backend statuses', () {
      expect(rankingInvestitureStatusKey('IN_PROGRESS'),
          'investiture.status.in_progress');
      expect(rankingInvestitureStatusKey(' submitted_for_validation '),
          'investiture.status.submitted');
    });

    test('falls back to localized in-progress for unknown statuses', () {
      expect(rankingInvestitureStatusKey('unexpected_status'),
          'investiture.status.in_progress');
    });
  });
}
