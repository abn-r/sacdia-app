import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity_rsvp.dart';
import 'package:sacdia_app/features/activities/domain/repositories/activities_repository.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/activities/presentation/views/activity_attendance_view.dart';
import 'package:sacdia_app/features/activities/presentation/views/activity_manual_attendance_view.dart';
import 'package:sacdia_app/features/activities/presentation/views/activity_my_qr_view.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/qr/domain/entities/qr_member_token.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';

import '../../../family/family_test_harness.dart';

class _FakeAuth extends AuthNotifier {
  @override
  Future<UserEntity?> build() async => const UserEntity(
        id: 'u1',
        name: 'Ana Ruiz',
        postRegisterComplete: true,
      );
}

class _FakeToken extends QrMemberTokenNotifier {
  @override
  Future<QrMemberToken> build() async => QrMemberToken(
        token: 'tok',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        expiresIn: 86400,
      );
}

class _FakeRepo implements ActivitiesRepository {
  _FakeRepo(this.roster);

  final List<AttendanceRosterMember> roster;
  List<String>? saved;

  @override
  Future<Either<Failure, List<AttendanceRosterMember>>> getAttendanceRoster(
    int activityId,
  ) async =>
      Right(roster);

  @override
  Future<Either<Failure, int>> registerAttendance(
    int activityId,
    List<String> userIds,
  ) async {
    saved = userIds;
    return Right(userIds.length);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AttendanceRosterMember _member(String id, String name,
        {bool confirmed = false, String? rsvp}) =>
    AttendanceRosterMember(
      userId: id,
      name: name,
      imageUrl: null,
      rsvp: rsvp,
      confirmed: confirmed,
    );

Activity _activity({List<String>? attendees, int platform = 0}) => Activity(
      id: 5,
      name: 'Caminata al malecón',
      activityPlace: 'Malecón',
      activityType: 2,
      platform: platform,
      active: true,
      clubSectionId: 1,
      clubTypeId: 2,
      clubTypeName: 'Conquistadores',
      attendees: attendees,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    required _FakeRepo repo,
    Activity? activity,
    bool pushed = false,
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(_FakeAuth.new),
        activitiesRepositoryProvider.overrideWithValue(repo),
        activityDetailProvider
            .overrideWith((ref, id) async => activity ?? _activity()),
      ],
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => pushed
              ? Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => screen),
                    ),
                    child: const Text('open'),
                  ),
                )
              : screen,
        ),
      ],
    );
    await tester.pumpAndSettle();
    if (pushed) {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }
  }

  final roster = [
    _member('u1', 'Ana Ruiz'),
    _member('u2', 'Bruno Méndez', confirmed: true, rsvp: 'going'),
    _member('u3', 'Lucía Pérez'),
  ];

  group('A · staff panel', () {
    testWidgets('shows X de Y, who is registered and both actions',
        (tester) async {
      await pumpScreen(
        tester,
        const ActivityAttendanceView(
          activityId: 5,
          activityName: 'Caminata al malecón',
          isVirtual: false,
        ),
        repo: _FakeRepo(roster),
      );

      expect(find.text('Asistencia'), findsOneWidget);
      expect(find.text('Caminata al malecón'), findsOneWidget);
      expect(find.text('1 de 3'), findsOneWidget);
      expect(find.text('faltan 2'), findsOneWidget);
      expect(find.text('REGISTRADOS'), findsOneWidget);
      expect(find.text('Bruno Méndez'), findsOneWidget);
      expect(find.text('Ana Ruiz'), findsNothing);
      expect(find.text('Escanear QR'), findsOneWidget);
      expect(find.text('Marcar a mano'), findsOneWidget);
    });

    testWidgets('virtual activities have no QR, only manual marking',
        (tester) async {
      await pumpScreen(
        tester,
        const ActivityAttendanceView(
          activityId: 5,
          activityName: 'Reunión',
          isVirtual: true,
        ),
        repo: _FakeRepo(roster),
      );

      expect(find.text('Escanear QR'), findsNothing);
      expect(find.text('Marcar a mano'), findsOneWidget);
    });

    testWidgets('empty state when nobody is registered', (tester) async {
      await pumpScreen(
        tester,
        const ActivityAttendanceView(
          activityId: 5,
          activityName: 'Reunión',
          isVirtual: false,
        ),
        repo: _FakeRepo([_member('u1', 'Ana Ruiz')]),
      );

      expect(find.text('0 de 1'), findsOneWidget);
      expect(find.text('Aún no hay nadie registrado'), findsOneWidget);
    });
  });

  group('D · marcar a mano', () {
    Future<_FakeRepo> pumpManual(WidgetTester tester) async {
      final repo = _FakeRepo(roster);
      await pumpScreen(
        tester,
        const ActivityManualAttendanceView(
          activityId: 5,
          activityName: 'Caminata al malecón',
        ),
        repo: repo,
        pushed: true,
      );
      return repo;
    }

    Finder row(String id) => find.byKey(ValueKey('manual-$id'));

    testWidgets('tapping a row marks it without moving it, then saves',
        (tester) async {
      final repo = await pumpManual(tester);

      expect(find.text('MIEMBROS'), findsOneWidget);
      expect(find.text('1 de 3 presentes'), findsOneWidget);
      final save = find.byKey(const ValueKey('manual-save'));
      expect(tester.widget<SacButton>(save).onPressed, isNull);

      final before = tester.getTopLeft(row('u1'));
      final order = [
        tester.getTopLeft(row('u1')).dy,
        tester.getTopLeft(row('u2')).dy,
        tester.getTopLeft(row('u3')).dy,
      ];
      expect(order, orderedEquals([...order]..sort()));

      await tester.tap(find.text('Ana Ruiz'));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(row('u1')), before);
      expect(find.text('2 de 3 presentes'), findsOneWidget);
      expect(tester.widget<SacButton>(save).onPressed, isNotNull);
      expect(find.text('Asistencia marcada: Ana Ruiz'), findsOneWidget);

      await tester.tap(save);
      await tester.pumpAndSettle();

      expect(repo.saved, unorderedEquals(['u1', 'u2']));
      expect(find.text('Asistencia guardada'), findsOneWidget);
    });

    testWidgets('the notice offers Deshacer, which reverts the toggle',
        (tester) async {
      await pumpManual(tester);

      await tester.tap(find.text('Ana Ruiz'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 3 presentes'), findsOneWidget);

      // A second toggle replaces the first notice instead of stacking.
      await tester.tap(find.text('Bruno Méndez'));
      await tester.pumpAndSettle();
      expect(find.text('Asistencia marcada: Ana Ruiz'), findsNothing);
      expect(find.text('Asistencia quitada: Bruno Méndez'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);

      await tester.tap(find.text('Deshacer'));
      await tester.pumpAndSettle();
      expect(find.text('2 de 3 presentes'), findsOneWidget);
      expect(
        tester
            .widget<Switch>(
              find.descendant(of: row('u2'), matching: find.byType(Switch)),
            )
            .value,
        isTrue,
      );
    });

    testWidgets('Faltan view collapses a row once it is marked',
        (tester) async {
      await pumpManual(tester);

      await tester.tap(find.byKey(const ValueKey('manual-filter-missing')));
      await tester.pumpAndSettle();
      expect(row('u2'), findsNothing);
      expect(row('u1'), findsOneWidget);

      await tester.tap(find.text('Ana Ruiz'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(row('u1'), findsOneWidget); // still collapsing
      await tester.pumpAndSettle();
      expect(row('u1'), findsNothing);
      expect(row('u3'), findsOneWidget);
    });

    testWidgets('asks before leaving with unsaved changes', (tester) async {
      await pumpManual(tester);

      await tester.tap(find.text('Ana Ruiz'));
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Tienes cambios sin guardar'), findsOneWidget);

      await tester.tap(find.text('Seguir marcando'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar a mano'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salir'));
      await tester.pumpAndSettle();
      expect(find.text('Marcar a mano'), findsNothing);
    });

    testWidgets('shows the RSVP answer only when asked to', (tester) async {
      await pumpScreen(
        tester,
        const ActivityManualAttendanceView(
          activityId: 5,
          activityName: 'Reunión',
        ),
        repo: _FakeRepo(roster),
      );
      expect(find.text('Hará lo posible'), findsNothing);

      await pumpScreen(
        tester,
        const ActivityManualAttendanceView(
          activityId: 5,
          activityName: 'Reunión',
          showRsvp: true,
        ),
        repo: _FakeRepo(roster),
      );
      expect(find.text('Hará lo posible'), findsOneWidget);
      expect(find.text('Sin respuesta'), findsNWidgets(2));
    });
  });

  group('B · mi QR', () {
    testWidgets('switches to registered when the user shows up in attendees',
        (tester) async {
      var attendees = <String>[];
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpFamilyApp(
        tester,
        overrides: [
          authNotifierProvider.overrideWith(_FakeAuth.new),
          activitiesRepositoryProvider.overrideWithValue(_FakeRepo(roster)),
          activityDetailProvider.overrideWith(
            (ref, id) async => _activity(attendees: List.of(attendees)),
          ),
          qrMemberTokenProvider.overrideWith(_FakeToken.new),
        ],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const ActivityMyQrView(
              activityId: 5,
              activityName: 'Caminata al malecón',
              sectionName: 'Conquistadores',
            ),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Mi asistencia'), findsOneWidget);
      expect(find.text('Muestra este código'), findsOneWidget);
      expect(
          find.text('Un líder lo escanea para registrarte.'), findsOneWidget);
      expect(find.text('Ana Ruiz · Conquistadores'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);

      attendees = ['u1'];
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.text('Asistencia registrada'), findsOneWidget);
      expect(find.text('Muestra este código'), findsNothing);

      // Unmount so the poll timer is cancelled by dispose.
      await tester.pumpWidget(const SizedBox());
    });
  });
}
