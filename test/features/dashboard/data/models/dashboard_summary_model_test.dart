import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/dashboard/data/models/dashboard_summary_model.dart';

void main() {
  group('DashboardSummaryModel', () {
    test('parses current class investiture status when backend provides it',
        () {
      final model = DashboardSummaryModel.fromJson({
        'user_name': 'Ada',
        'current_class_name': 'Amigo',
        'current_class_id': 10,
        'investiture_status': 'EXPIRED',
        'class_progress': 50,
        'honors_completed': 1,
        'honors_in_progress': 2,
        'upcoming_activities': <dynamic>[],
      });

      expect(model.currentClassInvestitureStatus, 'EXPIRED');
      expect(model.isCurrentClassExpired, isTrue);
      expect(model.toJson()['investiture_status'], 'EXPIRED');
    });

    test(
        'keeps missing current class investiture status as non-expired fallback',
        () {
      final model = DashboardSummaryModel.fromJson({
        'user_name': 'Ada',
        'class_progress': 50,
        'honors_completed': 1,
        'honors_in_progress': 2,
        'upcoming_activities': <dynamic>[],
      });

      expect(model.currentClassInvestitureStatus, isNull);
      expect(model.isCurrentClassExpired, isFalse);
    });
  });
}
