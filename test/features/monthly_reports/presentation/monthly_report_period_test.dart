import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/monthly_reports/presentation/utils/monthly_report_period.dart';

void main() {
  test('preparation period uses the current month, not the previous month', () {
    final period = MonthlyReportPeriod.forPreparation(
      DateTime(2026, 5, 28),
    );

    expect(period.month, 5);
    expect(period.year, 2026);
  });
}
