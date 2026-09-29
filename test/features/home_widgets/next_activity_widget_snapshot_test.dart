import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/home_widgets/domain/next_activity_widget_link.dart';
import 'package:sacdia_app/features/home_widgets/domain/next_activity_widget_snapshot.dart';

DashboardSummary _summary({
  String? clubName,
  List<UpcomingActivity> activities = const [],
}) {
  return DashboardSummary(
    userName: 'Ana',
    clubName: clubName,
    classProgress: 0,
    honorsCompleted: 0,
    honorsInProgress: 0,
    upcomingActivities: activities,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es');
  });

  test('usa la primera actividad, la fecha y el club', () {
    final snapshot = NextActivityWidgetSnapshot.fromSummary(
      _summary(
        clubName: ' Club Norte ',
        activities: [
          UpcomingActivity(
            id: 42,
            title: 'Caminata',
            activityDate: DateTime(2026, 9, 26),
            activityTime: '09:00',
          ),
          UpcomingActivity(
            id: 99,
            title: 'Otra',
            activityDate: DateTime(2026, 10, 1),
          ),
        ],
      ),
      emptyTitle: 'Sin actividades',
      localeName: 'es',
    );

    final expectedDate = DateFormat('EEE d MMM', 'es').format(
      DateTime(2026, 9, 26),
    );

    expect(snapshot.hasActivity, isTrue);
    expect(snapshot.activityId, 42);
    expect(snapshot.title, 'Caminata');
    expect(snapshot.clubName, 'Club Norte');
    expect(snapshot.dateLabel, '$expectedDate · 09:00');
    expect(snapshot.day, '26');
    expect(snapshot.timeLabel, '09:00');
    expect(snapshot.weekday, 'SÁB');
    expect(snapshot.month, 'SEPT');
  });

  test('sin actividades deja el aviso y el club', () {
    final snapshot = NextActivityWidgetSnapshot.fromSummary(
      _summary(clubName: 'Club Norte'),
      emptyTitle: 'Sin actividades',
      localeName: 'es',
    );

    expect(snapshot.hasActivity, isFalse);
    expect(snapshot.activityId, isNull);
    expect(snapshot.title, 'Sin actividades');
    expect(snapshot.dateLabel, isEmpty);
    expect(snapshot.day, isEmpty);
    expect(snapshot.clubName, 'Club Norte');
  });

  test('el enlace del widget lleva el id de la actividad', () {
    final uri = nextActivityWidgetLaunchUri(42);

    expect(activityIdFromWidgetUri(uri), 42);
    expect(uri.queryParameters.containsKey('homeWidget'), isTrue);
    expect(activityIdFromWidgetUri(Uri.parse('io.sacdia.app://auth/callback')),
        isNull);
    expect(activityIdFromWidgetUri(null), isNull);
  });
}
