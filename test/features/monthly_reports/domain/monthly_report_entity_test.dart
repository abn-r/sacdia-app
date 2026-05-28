import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/monthly_reports/domain/entities/monthly_report.dart';

void main() {
  test('draft reports are editable but not manually generated from mobile', () {
    const report = MonthlyReport(
      id: 'report-1',
      enrollmentId: 'enrollment-1',
      month: 4,
      year: 2026,
      status: 'draft',
    );

    expect(report.canEditManualData, isTrue);
    expect(report.canGenerate, isFalse);
  });

  test('serializes empty text fields as null so backend clears previous values',
      () {
    const manualData = MonthlyReportManualData(
      planningMeetings: 0,
      clubParticipationDescription: null,
      communityServiceDescription: null,
    );

    final json = manualData.toJson();

    expect(json['planning_meetings'], 0);
    expect(json.containsKey('club_participation_description'), isTrue);
    expect(json['club_participation_description'], isNull);
    expect(json.containsKey('community_service_description'), isTrue);
    expect(json['community_service_description'], isNull);
  });
}
