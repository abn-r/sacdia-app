import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/monthly_reports/data/models/monthly_report_model.dart';

void main() {
  test('parses backend snapshot_data and manual_data for report detail', () {
    final model = MonthlyReportModel.fromJson({
      'monthly_report_id': 'report-1',
      'club_enrollment_id': 'enrollment-1',
      'month': 4,
      'year': 2026,
      'status': 'generated',
      'generated_at': '2026-05-01T10:00:00.000Z',
      'club_enrollment': {
        'club_section': {
          'clubs': {'name': 'ACV Conquistadores'},
          'club_types': {'name': 'Conquistadores'},
        },
      },
      'snapshot_data': {
        'member_count': 35,
        'meeting_days': 'Sábado 16:00',
        'directiva': [
          {'name': 'Abner', 'role': 'Director'},
        ],
        'honors': {
          'started': 7,
          'completed': 3,
          'items': [
            {'name': 'Primeros Auxilios', 'status': 'completed'},
          ],
        },
        'activities': {
          'total': 9,
          'items': [
            {
              'name': 'Caminata',
              'date': '2026-04-10T00:00:00.000Z',
              'type': 'Regular',
              'attendees': 24,
            },
          ],
        },
        'finances': {
          'income': 1418,
          'expenses': 250,
          'balance': 1168,
          'total_balance': 3200,
          'transactions': 4,
        },
      },
      'manual_data': {
        'planning_meetings': 2,
        'parent_meetings': 1,
        'youth_council_attendance': 3,
        'church_board_attendance': 1,
        'soul_target': 5,
        'unbaptized_members': 4,
        'bible_studies_receiving': 2,
        'has_weekly_bible_instruction': true,
        'bible_studies_given': true,
        'literature_distributed': false,
        'baptized_this_month': 1,
        'total_baptized': 3,
        'club_participation_description': 'Participación en distrito',
        'community_service_description': 'Limpieza del parque',
        'certificates_delivered': true,
        'members_have_booklet': true,
        'booklet_requirements_signed': false,
      },
    });

    final report = model.toEntity();

    expect(report.clubName, 'ACV Conquistadores');
    expect(report.clubType, 'Conquistadores');
    expect(report.generatedAt, DateTime.parse('2026-05-01T10:00:00.000Z'));
    expect(report.snapshot?.memberCount, 35);
    expect(report.snapshot?.meetingDays, 'Sábado 16:00');
    expect(report.snapshot?.directiva.single.name, 'Abner');
    expect(report.snapshot?.honors.completed, 3);
    expect(report.snapshot?.honors.items.single.name, 'Primeros Auxilios');
    expect(report.snapshot?.activities.total, 9);
    expect(report.snapshot?.activities.items.single.attendees, 24);
    expect(report.snapshot?.finances.income, 1418);
    expect(report.snapshot?.finances.totalBalance, 3200);
    expect(report.manualData?.planningMeetings, 2);
    expect(
        report.manualData?.communityServiceDescription, 'Limpieza del parque');
    expect(report.manualData?.certificatesDelivered, isTrue);

    // Legacy summary fields stay populated for older widgets.
    expect(report.totalActivities, 9);
    expect(report.totalMembers, 35);
    expect(report.notes, 'Participación en distrito');
  });
}
