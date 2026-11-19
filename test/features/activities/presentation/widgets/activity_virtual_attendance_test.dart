import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity_rsvp.dart';
import 'package:sacdia_app/features/activities/domain/repositories/activities_repository.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_state_panel.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_virtual_attendance.dart';

import '../../../family/family_test_harness.dart';

class _FakeRepo implements ActivitiesRepository {
  final saved = <String>[];

  @override
  Future<Either<Failure, MyActivityRsvp>> getMyRsvp(int activityId) async =>
      const Right(MyActivityRsvp(status: null, eligible: true));

  @override
  Future<Either<Failure, String>> setMyRsvp(
    int activityId,
    String status,
  ) async {
    saved.add(status);
    return Right(status);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<_FakeRepo> pumpAttendance(WidgetTester tester) async {
    final repo = _FakeRepo();
    await pumpFamilyApp(
      tester,
      overrides: [activitiesRepositoryProvider.overrideWithValue(repo)],
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
            body: ActivityVirtualAttendance(activityId: 1),
          ),
        ),
      ],
    );
    await tester.pumpAndSettle();
    return repo;
  }

  double thumbOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(find.byKey(const ValueKey('rsvp-thumb')))
      .opacity;

  Alignment thumbAlignment(WidgetTester tester) => tester
      .widget<AnimatedAlign>(find.byKey(const ValueKey('rsvp-thumb-align')))
      .alignment as Alignment;

  testWidgets('M8: no thumb before the first answer, then it moves',
      (tester) async {
    final repo = await pumpAttendance(tester);

    expect(find.text('¿Asistirás?'), findsOneWidget);
    expect(find.text('Puedes cambiarlo cuando quieras.'), findsOneWidget);
    expect(thumbOpacity(tester), 0);

    await tester.tap(find.text('Asistiré'));
    await tester.pumpAndSettle();
    expect(repo.saved, ['going']);
    expect(thumbOpacity(tester), 1);
    expect(thumbAlignment(tester), Alignment.centerRight);
    expect(find.text('Asistirás'), findsOneWidget);
    expect(
        find.text('La directiva confirma la asistencia real.'), findsOneWidget);

    await tester.tap(find.text('No asistiré'));
    await tester.pumpAndSettle();
    expect(repo.saved, ['going', 'not_going']);
    expect(thumbAlignment(tester), Alignment.centerLeft);
    expect(find.text('No asistirás'), findsOneWidget);
    expect(find.text('Gracias por avisar.'), findsOneWidget);
  });

  testWidgets('M8: the first answer places the thumb without travelling',
      (tester) async {
    await pumpAttendance(tester);

    await tester.tap(find.text('Asistiré'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    // Already under the chosen option while it fades in.
    expect(thumbAlignment(tester), Alignment.centerRight);
    expect(
      tester
          .widget<AnimatedAlign>(find.byKey(const ValueKey('rsvp-thumb-align')))
          .duration,
      Duration.zero,
    );
    await tester.pumpAndSettle();
  });

  group('panel weekday and time', () {
    Future<void> pumpPanel(WidgetTester tester, String time) async {
      final day = DateTime.now().add(const Duration(days: 3));
      await pumpFamilyApp(
        tester,
        overrides: const [],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
              body: ActivityStatePanel(
                activity: Activity(
                  id: 1,
                  name: 'Reunión',
                  activityPlace: 'Sede',
                  activityType: 1,
                  platform: 0,
                  active: true,
                  clubSectionId: 1,
                  clubTypeId: 2,
                  activityDate: DateTime(day.year, day.month, day.day),
                  activityTime: time,
                ),
              ),
            ),
          ),
        ],
      );
      await tester.pumpAndSettle();
    }

    testWidgets('one o\'clock reads "a la 1:00"', (tester) async {
      await pumpPanel(tester, '01:00');
      expect(find.textContaining('a la 1:00'), findsOneWidget);
    });

    testWidgets('other hours keep "a las"', (tester) async {
      await pumpPanel(tester, '13:00');
      expect(find.textContaining('a las 13:00'), findsOneWidget);
      await pumpPanel(tester, '11:00');
      expect(find.textContaining('a las 11:00'), findsOneWidget);
    });
  });
}
