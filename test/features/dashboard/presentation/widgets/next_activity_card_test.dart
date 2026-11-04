import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/widgets/next_activity_card.dart';
import '../../../../support/l10n_test_support.dart';

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

UpcomingActivity _activity({
  required int inDays,
  String? time = '09:30',
  String? location = 'Templo central',
  String title = 'Campamento de zona',
}) {
  final today = _today();
  return UpcomingActivity(
    id: 11,
    title: title,
    activityDate: DateTime(today.year, today.month, today.day + inDays),
    activityTime: time,
    location: location,
  );
}

Future<void> _pump(
  WidgetTester tester,
  UpcomingActivity? activity, {
  ValueChanged<UpcomingActivity>? onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: NextActivityCard(activity: activity, onTap: onTap),
      ),
    ),
  );
}

void main() {
  setUpAll(loadSpanishTranslations);

  group('NextActivityCard', () {
    testWidgets('today shows "Hoy" and date badge parts', (tester) async {
      final activity = _activity(inDays: 0);
      await _pump(tester, activity);

      expect(find.text('Próxima actividad'), findsOneWidget);
      expect(find.text('Campamento de zona'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(
        find.text(DateFormat('dd').format(activity.activityDate)),
        findsOneWidget,
      );
      expect(
        find.text(
            DateFormat('MMM').format(activity.activityDate).toUpperCase()),
        findsOneWidget,
      );
      expect(find.byType(SacBadge), findsOneWidget);
    });

    testWidgets('tomorrow shows "Mañana"', (tester) async {
      await _pump(tester, _activity(inDays: 1));

      expect(find.text('Mañana'), findsOneWidget);
    });

    testWidgets('later shows "En N días" and a weekday meta line',
        (tester) async {
      final activity = _activity(inDays: 3);
      await _pump(tester, activity);

      expect(find.text('En 3 días'), findsOneWidget);
      final weekday = DateFormat('EEEE').format(activity.activityDate);
      expect(find.text('$weekday · 09:30 · Templo central'), findsOneWidget);
    });

    testWidgets('a week or more away uses the short date in the meta line',
        (tester) async {
      final activity = _activity(inDays: 10, time: null, location: null);
      await _pump(tester, activity);

      expect(find.text('En 10 días'), findsOneWidget);
      expect(
        find.text(DateFormat('dd MMM').format(activity.activityDate)),
        findsOneWidget,
      );
    });

    testWidgets('tapping reports the activity', (tester) async {
      UpcomingActivity? tapped;
      final activity = _activity(inDays: 2);
      await _pump(tester, activity, onTap: (a) => tapped = a);

      await tester.tap(find.text('Campamento de zona'));
      await tester.pump();

      expect(tapped, activity);
    });

    testWidgets('no activity renders the inline empty state', (tester) async {
      await _pump(tester, null);

      expect(find.byType(SacEmptyState), findsOneWidget);
      expect(find.text('No hay actividades programadas'), findsOneWidget);
      expect(find.byType(SacBadge), findsNothing);
    });
  });

  group('nextUpcomingActivity', () {
    test('returns the first activity that has not passed', () {
      final past = _activity(inDays: -1, title: 'Ayer');
      final today = _activity(inDays: 0, title: 'Hoy');
      final later = _activity(inDays: 4, title: 'Luego');

      expect(nextUpcomingActivity([past, today, later])?.title, 'Hoy');
      expect(nextUpcomingActivity([past, later])?.title, 'Luego');
      expect(nextUpcomingActivity([past]), isNull);
      expect(nextUpcomingActivity(const []), isNull);
    });
  });
}
