import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity_rsvp.dart';
import 'package:sacdia_app/features/activities/domain/repositories/activities_repository.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/activities/presentation/views/activity_detail_view.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_detail_actions.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_map_card.dart';
import 'package:sacdia_app/features/activities/presentation/widgets/activity_state_panel.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

import '../../../family/family_test_harness.dart';

class _FakeAuth extends AuthNotifier {
  _FakeAuth(this.user);

  final UserEntity user;

  @override
  Future<UserEntity?> build() async => user;
}

class _FakeDelete extends DeleteActivityNotifier {
  @override
  Future<bool> delete(int activityId) async => true;
}

/// Only the calls the detail makes; anything else would be a test bug.
class _FakeRepo implements ActivitiesRepository {
  @override
  Future<Either<Failure, MyActivityRsvp>> getMyRsvp(int activityId) async =>
      const Right(MyActivityRsvp(status: null, eligible: false));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

UserEntity _user({
  List<String> permissions = const [],
  List<String> capabilities = const [],
}) =>
    UserEntity(
      id: 'u1',
      name: 'Ana',
      postRegisterComplete: true,
      authorization: AuthorizationSnapshot(
        effectivePermissions: permissions,
        capabilities: capabilities,
      ),
    );

DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + offset);
}

Activity _activity({
  int platform = 0,
  int dayOffset = 1,
  String time = '08:00',
  String? linkMeet,
  List<String>? attendees,
  DateTime? endDate,
}) =>
    Activity(
      id: 5,
      name: 'Caminata al malecón',
      activityPlace: platform == 1 ? '' : 'Malecón de Veracruz',
      activityType: 2,
      platform: platform,
      active: true,
      clubSectionId: 1,
      clubTypeId: 2,
      clubTypeName: 'Conquistadores',
      activityDate: _day(dayOffset),
      activityEndDate: endDate,
      activityTime: time,
      lat: platform == 1 ? null : 19.17,
      longitude: platform == 1 ? null : -96.13,
      linkMeet: linkMeet,
      attendees: attendees,
      creatorName: 'Mateo Herrera',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<void> pumpDetail(
    WidgetTester tester,
    Activity activity, {
    UserEntity? user,
    bool deleteOk = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => _FakeAuth(user ?? _user())),
        activityDetailProvider.overrideWith((ref, id) async => activity),
        activitiesRepositoryProvider.overrideWithValue(_FakeRepo()),
        if (deleteOk)
          deleteActivityNotifierProvider.overrideWith(_FakeDelete.new),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityDetailView(
                      activityId: activity.id,
                      mapBuilder: (_, __, ___) =>
                          const SizedBox(key: ValueKey('fake-map')),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  final moreAction = find.byKey(const ValueKey('activity-more-action'));

  group('top bar', () {
    testWidgets('shows the standard title and no ⋯ without permissions',
        (tester) async {
      await pumpDetail(tester, _activity());

      expect(find.text('Actividad'), findsOneWidget);
      expect(moreAction, findsNothing);
    });

    testWidgets('⋯ with only update offers Editar', (tester) async {
      await pumpDetail(
        tester,
        _activity(),
        user: _user(permissions: const ['activities:update']),
      );

      await tester.tap(moreAction);
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Eliminar'), findsNothing);
    });

    testWidgets('⋯ with only delete offers Eliminar', (tester) async {
      await pumpDetail(
        tester,
        _activity(),
        user: _user(permissions: const ['activities:delete']),
      );

      await tester.tap(moreAction);
      await tester.pumpAndSettle();

      expect(find.text('Editar'), findsNothing);
      expect(find.text('Eliminar'), findsOneWidget);
    });

    testWidgets('with both, Eliminar is last and red', (tester) async {
      await pumpDetail(
        tester,
        _activity(),
        user: _user(
          permissions: const ['activities:update', 'activities:delete'],
        ),
      );

      await tester.tap(moreAction);
      await tester.pumpAndSettle();

      final edit = tester.getTopLeft(find.text('Editar')).dy;
      final delete = tester.getTopLeft(find.text('Eliminar')).dy;
      expect(delete, greaterThan(edit));
      final style = tester.widget<Text>(find.text('Eliminar')).style;
      expect(style?.color, AppColors.error);
    });

    testWidgets('a successful delete shows a success snackbar, not an error',
        (tester) async {
      await pumpDetail(
        tester,
        _activity(),
        user: _user(permissions: const ['activities:delete']),
        deleteOk: true,
      );

      await tester.tap(moreAction);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      // Confirmation dialog: its destructive button is the last "Eliminar".
      await tester.tap(find.text('Eliminar').last);
      await tester.pumpAndSettle();

      expect(find.text('Actividad eliminada correctamente'), findsOneWidget);
      final snack = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(snack.backgroundColor, isNull);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.byType(HugeIcon),
        ),
        findsOneWidget,
      );
    });
  });

  group('map card', () {
    testWidgets('is shown for in-person activities with the place',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpDetail(tester, _activity());

      expect(find.byType(ActivityMapCard), findsOneWidget);
      expect(find.byKey(const ValueKey('fake-map')), findsOneWidget);
      expect(find.text('Malecón de Veracruz'), findsOneWidget);
      expect(find.text('Abrir en mapas'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp('Mapa: Malecón de Veracruz, abrir en mapas'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('is shown for hybrid activities', (tester) async {
      await pumpDetail(tester, _activity(platform: 2));

      expect(find.byType(ActivityMapCard), findsOneWidget);
    });

    testWidgets('is hidden for virtual activities', (tester) async {
      await pumpDetail(
        tester,
        _activity(platform: 1, linkMeet: 'https://meet.google.com/xyz-abcd'),
      );

      expect(find.byType(ActivityMapCard), findsNothing);
      expect(find.text('Google Meet'), findsOneWidget);
      expect(find.text('meet.google.com/xyz-abcd'), findsOneWidget);
    });
  });

  group('state panel in the detail', () {
    testWidgets('upcoming shows the countdown and weekday with time',
        (tester) async {
      await pumpDetail(tester, _activity(dayOffset: 1));

      expect(find.text('Mañana'), findsOneWidget);
      expect(find.textContaining('a las 8:00'), findsOneWidget);
    });

    testWidgets('in progress after the start time of today', (tester) async {
      await pumpDetail(tester, _activity(dayOffset: 0, time: '00:00'));

      expect(find.text('En curso'), findsOneWidget);
    });

    testWidgets('finished shows how long ago and who attended', (tester) async {
      await pumpDetail(
        tester,
        _activity(dayOffset: -3, attendees: const ['a', 'b']),
      );

      expect(find.text('Finalizada hace 3 días'), findsOneWidget);
      expect(find.text('Asistieron 2'), findsOneWidget);
    });
  });

  group('footer action', () {
    testWidgets('member sees Mostrar mi QR on an upcoming in-person activity',
        (tester) async {
      await pumpDetail(tester, _activity());

      expect(find.byKey(const ValueKey('activity-footer-qr')), findsOneWidget);
      expect(find.text('Mostrar mi QR'), findsOneWidget);
    });

    testWidgets('member has no QR once the activity finished', (tester) async {
      await pumpDetail(tester, _activity(dayOffset: -2));

      expect(find.text('Mostrar mi QR'), findsNothing);
      expect(find.byKey(const ValueKey('activity-footer-qr')), findsNothing);
    });

    testWidgets('staff keeps Asistencia, even when finished', (tester) async {
      await pumpDetail(
        tester,
        _activity(dayOffset: -2),
        user: _user(permissions: const ['attendance:manage']),
      );

      expect(
        find.byKey(const ValueKey('activity-footer-attendance')),
        findsOneWidget,
      );
      expect(find.text('Mostrar mi QR'), findsNothing);
    });

    testWidgets('virtual activity with a link offers Unirse a la reunión',
        (tester) async {
      await pumpDetail(
        tester,
        _activity(platform: 1, linkMeet: 'https://meet.google.com/xyz-abcd'),
      );

      expect(
        find.byKey(const ValueKey('activity-footer-join')),
        findsOneWidget,
      );
      expect(find.text('Unirse a la reunión'), findsOneWidget);
    });
  });

  group('panel and phase logic', () {
    final base = Activity(
      id: 1,
      name: 'x',
      activityPlace: 'p',
      activityType: 1,
      platform: 0,
      active: true,
      clubSectionId: 1,
      clubTypeId: 1,
      activityDate: DateTime(2026, 11, 21),
      activityTime: '08:00',
    );

    test('phaseAt uses date AND time', () {
      expect(
          base.phaseAt(DateTime(2026, 11, 21, 7, 59)), ActivityPhase.upcoming);
      expect(base.phaseAt(DateTime(2026, 11, 21, 8)), ActivityPhase.inProgress);
      expect(base.phaseAt(DateTime(2026, 11, 21, 23, 59)),
          ActivityPhase.inProgress);
      expect(base.phaseAt(DateTime(2026, 11, 22)), ActivityPhase.finished);
    });

    test('a multi-day activity runs until the end of its last day', () {
      final camp = Activity(
        id: 2,
        name: 'c',
        activityPlace: 'p',
        activityType: 3,
        platform: 0,
        active: true,
        clubSectionId: 1,
        clubTypeId: 1,
        activityDate: DateTime(2026, 12, 4),
        activityEndDate: DateTime(2026, 12, 6),
        activityTime: '16:00',
      );
      expect(camp.phaseAt(DateTime(2026, 12, 5, 10)), ActivityPhase.inProgress);
      expect(camp.phaseAt(DateTime(2026, 12, 6, 22)), ActivityPhase.inProgress);
      expect(camp.phaseAt(DateTime(2026, 12, 7)), ActivityPhase.finished);
    });

    test('footer action by role and state', () {
      const upcoming = ActivityPhase.upcoming;
      const finished = ActivityPhase.finished;
      expect(
        activityFooterAction(base, upcoming, canManageAttendance: false),
        ActivityFooterAction.showMyQr,
      );
      expect(
        activityFooterAction(base, finished, canManageAttendance: false),
        ActivityFooterAction.none,
      );
      expect(
        activityFooterAction(base, finished, canManageAttendance: true),
        ActivityFooterAction.manageAttendance,
      );
      final virtual = Activity(
        id: 3,
        name: 'v',
        activityPlace: '',
        activityType: 1,
        platform: 1,
        active: true,
        clubSectionId: 1,
        clubTypeId: 1,
        linkMeet: 'https://meet.google.com/a',
      );
      expect(
        activityFooterAction(virtual, upcoming, canManageAttendance: true),
        ActivityFooterAction.joinMeeting,
      );
      expect(
        activityFooterAction(virtual, finished, canManageAttendance: false),
        ActivityFooterAction.none,
      );
    });

    testWidgets('panel renders upcoming, in progress and finished',
        (tester) async {
      Future<void> show(DateTime now) async {
        await pumpFamilyApp(
          tester,
          overrides: const [],
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => Scaffold(
                body: ActivityStatePanel(activity: base, now: now),
              ),
            ),
          ],
        );
        await tester.pumpAndSettle();
      }

      await show(DateTime(2026, 11, 19, 10));
      expect(find.text('En 2 días'), findsOneWidget);
      expect(find.text('Sábado a las 8:00'), findsOneWidget);

      await show(DateTime(2026, 11, 21, 9));
      expect(find.text('En curso'), findsOneWidget);

      await show(DateTime(2026, 11, 22, 9));
      expect(find.text('Finalizada ayer'), findsOneWidget);
    });
  });
}
