import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_attendees_section.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: child),
      );

  testWidgets('shows member initials instead of the user id', (tester) async {
    await tester.pumpWidget(host(
      const ActivityAttendeesSection(
        attendees: ['a0000001-0000-0000-0000-000000000001'],
        profiles: [
          ActivityAttendee(
            userId: 'a0000001-0000-0000-0000-000000000001',
            name: 'María',
            paternalLastName: 'López',
          ),
        ],
      ),
    ));

    expect(find.text('ML'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });

  testWidgets('falls back to a person icon when no profile is known',
      (tester) async {
    await tester.pumpWidget(host(
      const ActivityAttendeesSection(
        attendees: ['a0000001-0000-0000-0000-000000000001'],
      ),
    ));

    expect(find.text('A'), findsNothing);
    expect(find.byType(HugeIcon), findsOneWidget);
  });

  test('ActivityAttendee.initials handles missing last name and blanks', () {
    const onlyName = ActivityAttendee(userId: 'u1', name: ' ana ');
    const blank = ActivityAttendee(userId: 'u2', name: '');
    expect(onlyName.initials, 'A');
    expect(blank.initials, '');
  });
}
