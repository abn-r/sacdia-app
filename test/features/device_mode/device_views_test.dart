import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/evidence_staging_manager.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';
import 'package:sacdia_app/features/activities/presentation/providers/activities_providers.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/classes/domain/entities/class_requirement.dart';
import 'package:sacdia_app/features/classes/domain/entities/progressive_class.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/device_mode/presentation/providers/device_connectivity_provider.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/device_activity_detail_view.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/device_agenda_view.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/device_blocked_views.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/device_class_detail_view.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/device_classes_view.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/device_home_view.dart';
import 'package:sacdia_app/features/device_mode/presentation/views/device_requirement_view.dart';
import 'package:sacdia_app/features/qr/domain/entities/qr_member_token.dart';
import 'package:sacdia_app/features/qr/presentation/providers/qr_member_token_provider.dart';

import '../family/family_test_harness.dart';
import 'device_test_harness.dart';

class _FakeQr extends QrMemberTokenNotifier {
  _FakeQr({this.fail = false});

  final bool fail;

  @override
  Future<QrMemberToken> build() async {
    if (fail) throw Exception('403');
    return QrMemberToken(
      token: 'QR-TOKEN-1',
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
      expiresIn: 86400,
    );
  }
}

class _FakeRequirementNotifier extends RequirementNotifier {
  @override
  RequirementOperationState build(ClassProgressQuery arg) =>
      const RequirementOperationState();

  void emit(RequirementOperationState next) => state = next;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late FakeDeviceAuth auth;

  List<Override> base({
    List<ProgressiveClass> classes = const [mathClass],
    Object? classesError,
    List<Activity>? activities,
    bool online = true,
    bool qrFails = false,
    FakeDeviceAuth? authOverride,
    int? clubId = 7,
  }) {
    auth = authOverride ?? FakeDeviceAuth(deviceUser(clubId: clubId));
    return [
      authNotifierProvider.overrideWith(() => auth),
      userClassesProvider.overrideWith((ref) async {
        if (classesError != null) throw classesError;
        return classes;
      }),
      clubActivitiesProvider.overrideWith(
        (ref, params) async => activities ?? [activity(1)],
      ),
      activityDetailProvider.overrideWith(
        (ref, id) async => activity(
          id,
          attendees: const [
            ActivityAttendee(
                userId: 'x', name: 'Luis', paternalLastName: 'Pérez'),
          ],
        ),
      ),
      classWithProgressProvider
          .overrideWith((ref, query) async => classWithProgress()),
      qrMemberTokenProvider.overrideWith(() => _FakeQr(fail: qrFails)),
      deviceOnlineProvider.overrideWith((ref) => Stream.value(online)),
    ];
  }

  Future<void> pump(
    WidgetTester tester,
    Widget view, {
    List<Override>? overrides,
    List<GoRoute> extraRoutes = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await pumpFamilyApp(
      tester,
      overrides: overrides ?? base(),
      routes: [
        GoRoute(path: '/', builder: (_, __) => view),
        stubRoute(RouteNames.deviceClasses),
        stubRoute(RouteNames.deviceAgenda),
        GoRoute(
          path: RouteNames.deviceClassDetail,
          builder: (_, s) => Scaffold(
            body: Text('class:${s.pathParameters['classId']}'
                ':${s.uri.queryParameters['enrollmentId']}'),
          ),
        ),
        GoRoute(
          path: RouteNames.deviceRequirement,
          builder: (_, s) => Scaffold(
            body: Text('req:${s.pathParameters['requirementId']}'),
          ),
        ),
        GoRoute(
          path: RouteNames.deviceActivityDetail,
          builder: (_, s) =>
              Scaffold(body: Text('act:${s.pathParameters['activityId']}')),
        ),
        ...extraRoutes,
      ],
    );
    await tester.pumpAndSettle();
  }

  group('DeviceHomeView', () {
    testWidgets('greets the child and shows progress, activity and credential',
        (tester) async {
      await pump(tester, const DeviceHomeView());

      expect(find.text('Hola, Ana'), findsOneWidget);
      expect(find.text('Amigo'), findsOneWidget);
      expect(find.text('62%'), findsOneWidget);
      expect(find.text('Campamento'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('device_home_credential')), findsOneWidget);
      expect(find.text('Este teléfono: Tablet de Ana'), findsOneWidget);
    });

    testWidgets('the credential card disappears when the server denies it',
        (tester) async {
      await pump(tester, const DeviceHomeView(),
          overrides: base(qrFails: true));

      expect(
          find.byKey(const ValueKey('device_home_credential')), findsNothing);
      expect(find.byKey(const ValueKey('device_home_no_credential')),
          findsOneWidget);
    });

    testWidgets('offers nothing an account has', (tester) async {
      await pump(tester, const DeviceHomeView());

      for (final forbidden in [
        'Mi familia',
        'Perfil',
        'Seguridad',
        'Sesiones',
        'Eliminar cuenta',
        'Exportar',
        'Cambiar contraseña',
        'Cerrar sesión',
      ]) {
        expect(find.text(forbidden), findsNothing, reason: forbidden);
      }
      expect(find.text('Desvincular este teléfono'), findsOneWidget);
    });

    testWidgets('unlinking asks first and then signs out', (tester) async {
      await pump(tester, const DeviceHomeView());

      await tester.ensureVisible(find.byKey(const ValueKey('device_unlink')));
      await tester.tap(find.byKey(const ValueKey('device_unlink')));
      await tester.pumpAndSettle();
      expect(find.text('¿Desvincular este teléfono?'), findsOneWidget);
      expect(auth.signOutCalls, 0);

      await tester.tap(find.text('Desvincular').last);
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
    });

    testWidgets('cancelling the unlink dialog keeps the session',
        (tester) async {
      await pump(tester, const DeviceHomeView());

      await tester.ensureVisible(find.byKey(const ValueKey('device_unlink')));
      await tester.tap(find.byKey(const ValueKey('device_unlink')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 0);
    });

    testWidgets('without classes it explains how to get them', (tester) async {
      await pump(tester, const DeviceHomeView(),
          overrides: base(classes: const []));

      expect(find.textContaining('Todavía no tienes clases'), findsOneWidget);
    });

    testWidgets('without a club there is no activity call', (tester) async {
      await pump(tester, const DeviceHomeView(), overrides: base(clubId: null));

      expect(find.byKey(const ValueKey('device_home_next_activity')),
          findsNothing);
    });
  });

  group('DeviceClassesView', () {
    testWidgets('lists the enrolled classes and opens one', (tester) async {
      await pump(tester, const DeviceClassesView());

      expect(find.text('Amigo'), findsOneWidget);
      expect(find.text('62% completado'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('device_class_3')));
      await tester.pumpAndSettle();

      expect(find.text('class:3:99'), findsOneWidget);
    });

    testWidgets('a class without enrollment is not listed', (tester) async {
      await pump(
        tester,
        const DeviceClassesView(),
        overrides: base(
          classes: const [
            ProgressiveClass(id: 5, name: 'Guía', clubTypeId: 2),
          ],
        ),
      );

      expect(find.text('Guía'), findsNothing);
      expect(
          find.byKey(const ValueKey('device_classes_empty')), findsOneWidget);
    });

    testWidgets('an error offers a retry', (tester) async {
      await pump(
        tester,
        const DeviceClassesView(),
        overrides: base(classesError: Exception('offline')),
      );

      expect(
          find.byKey(const ValueKey('device_classes_error')), findsOneWidget);
      expect(find.text('Reintentar'), findsOneWidget);
    });
  });

  group('DeviceClassDetailView', () {
    testWidgets('shows requirements with their status and opens one',
        (tester) async {
      await pump(
          tester, const DeviceClassDetailView(classId: 3, enrollmentId: 99));

      expect(find.text('Módulo 1'), findsOneWidget);
      expect(find.text('Requisito 10'), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Enviado'), findsOneWidget);
      expect(find.text('Validado'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('device_requirement_10')));
      await tester.pumpAndSettle();

      expect(find.text('req:10'), findsOneWidget);
    });
  });

  group('DeviceRequirementView', () {
    testWidgets('a pending requirement can take evidence (online)',
        (tester) async {
      await pump(
        tester,
        const DeviceRequirementView(
            classId: 3, requirementId: 10, enrollmentId: 99),
      );

      expect(find.text('Requisito 10'), findsOneWidget);
      final manager = tester
          .widget<EvidenceStagingManager>(find.byType(EvidenceStagingManager));
      expect(manager.canModify, isTrue);
      expect(find.byKey(const ValueKey('device_requirement_offline')),
          findsNothing);
    });

    testWidgets('offline is read-only: nothing can be uploaded or sent',
        (tester) async {
      await pump(
        tester,
        const DeviceRequirementView(
            classId: 3, requirementId: 10, enrollmentId: 99),
        overrides: base(online: false),
      );

      final manager = tester
          .widget<EvidenceStagingManager>(find.byType(EvidenceStagingManager));
      expect(manager.canModify, isFalse);
      expect(find.byKey(const ValueKey('device_requirement_offline')),
          findsOneWidget);
    });

    testWidgets('a submitted requirement is read-only even online',
        (tester) async {
      await pump(
        tester,
        const DeviceRequirementView(
            classId: 3, requirementId: 11, enrollmentId: 99),
      );

      final manager = tester
          .widget<EvidenceStagingManager>(find.byType(EvidenceStagingManager));
      expect(manager.canModify, isFalse);
    });

    testWidgets("the reviewer's observation is shown", (tester) async {
      final overrides = base()
        ..add(
          classWithProgressProvider.overrideWith(
            (ref, query) async => classWithProgress(requirements: [
              requirement(
                10,
                status: RequirementStatus.observado,
                observation: 'Falta la foto del cuaderno',
              ),
            ]),
          ),
        );
      await pump(
        tester,
        const DeviceRequirementView(
            classId: 3, requirementId: 10, enrollmentId: 99),
        overrides: overrides,
      );

      expect(find.text('Falta la foto del cuaderno'), findsOneWidget);
      final manager = tester
          .widget<EvidenceStagingManager>(find.byType(EvidenceStagingManager));
      expect(manager.canModify, isTrue, reason: 'observed can be corrected');
    });

    group('action errors are translated by code, never raw', () {
      Future<void> fail(
        WidgetTester tester,
        String? code,
      ) async {
        await pump(
          tester,
          const DeviceRequirementView(
              classId: 3, requirementId: 10, enrollmentId: 99),
          overrides: [
            ...base(),
            requirementNotifierProvider
                .overrideWith(_FakeRequirementNotifier.new),
          ],
        );
        final container = ProviderScope.containerOf(
          tester.element(find.byType(DeviceRequirementView)),
        );
        const query = ClassProgressQuery(classId: 3, enrollmentId: 99);
        (container.read(requirementNotifierProvider(query).notifier)
                as _FakeRequirementNotifier)
            .emit(RequirementOperationState(
          errorMessage: 'RAW SERVER TEXT',
          errorCode: code,
        ));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
      }

      testWidgets('PRINCIPAL_SCOPE_DENIED gets a friendly message',
          (tester) async {
        await fail(tester, 'PRINCIPAL_SCOPE_DENIED');
        expect(find.text('Esta acción no está disponible para tu cuenta.'),
            findsOneWidget);
        expect(find.text('RAW SERVER TEXT'), findsNothing);
      });

      testWidgets('a known file error uses its own message', (tester) async {
        await fail(tester, 'FILE_TOO_LARGE');
        expect(find.text('RAW SERVER TEXT'), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      });

      testWidgets('an unknown or missing code is generic', (tester) async {
        await fail(tester, null);
        expect(
          find.text('No pudimos completar la acción. Inténtalo de nuevo.'),
          findsOneWidget,
        );
        expect(find.text('RAW SERVER TEXT'), findsNothing);
      });
    });

    testWidgets('an unknown requirement says so', (tester) async {
      await pump(
        tester,
        const DeviceRequirementView(
            classId: 3, requirementId: 999, enrollmentId: 99),
      );

      expect(find.byKey(const ValueKey('device_requirement_missing')),
          findsOneWidget);
    });
  });

  group('DeviceAgendaView', () {
    testWidgets('lists upcoming activities, never attendees', (tester) async {
      await pump(
        tester,
        const DeviceAgendaView(),
        overrides: base(activities: [
          activity(
            1,
            attendees: const [
              ActivityAttendee(
                  userId: 'x', name: 'Luis', paternalLastName: 'Pérez'),
            ],
          ),
          activity(2,
              name: 'Ayer',
              date: DateTime.now().subtract(const Duration(days: 2))),
        ]),
      );

      expect(find.text('Campamento'), findsOneWidget);
      expect(find.text('Parque Central'), findsOneWidget);
      expect(find.text('Ayer'), findsNothing,
          reason: 'past activities are hidden');
      expect(find.textContaining('Luis'), findsNothing);
    });

    testWidgets('without a club it says so', (tester) async {
      await pump(tester, const DeviceAgendaView(),
          overrides: base(clubId: null));
      expect(
          find.byKey(const ValueKey('device_agenda_no_club')), findsOneWidget);
    });

    testWidgets('with nothing coming up it says so', (tester) async {
      await pump(tester, const DeviceAgendaView(),
          overrides: base(activities: const []));
      expect(find.byKey(const ValueKey('device_agenda_empty')), findsOneWidget);
    });

    testWidgets('tapping an activity opens its detail', (tester) async {
      await pump(tester, const DeviceAgendaView());

      await tester.tap(find.byKey(const ValueKey('device_activity_1')));
      await tester.pumpAndSettle();

      expect(find.text('act:1'), findsOneWidget);
    });
  });

  group('DeviceActivityDetailView', () {
    testWidgets('shows what, when and where, and nobody else', (tester) async {
      await pump(tester, const DeviceActivityDetailView(activityId: 4));

      expect(find.text('Campamento'), findsOneWidget);
      expect(find.text('Parque Central'), findsOneWidget);
      expect(find.text('Trae tu mochila'), findsOneWidget);
      // La entidad trae un asistente; el teléfono jamás lo muestra.
      expect(find.textContaining('Luis'), findsNothing);
      expect(find.textContaining('Pérez'), findsNothing);
    });
  });

  group('blocking screens', () {
    testWidgets('pending terms: the child cannot accept them', (tester) async {
      await pump(tester, const DeviceLegalBlockView());

      expect(find.text('Falta un paso de tu tutor'), findsOneWidget);
      expect(find.textContaining('nuevos términos'), findsOneWidget);
      expect(find.text('Aceptar'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('device_legal_refresh')));
      await tester.pump();
      expect(auth.refreshCalls, 1);
    });

    testWidgets('incomplete registration never opens post-registration',
        (tester) async {
      await pump(tester, const DeviceRegistrationPendingView());

      expect(find.text('Falta terminar tu registro'), findsOneWidget);
      await tester
          .tap(find.byKey(const ValueKey('device_registration_refresh')));
      await tester.pump();
      expect(auth.refreshCalls, 1);
    });

    testWidgets('both can unlink the phone', (tester) async {
      await pump(tester, const DeviceLegalBlockView());
      await tester.tap(find.byKey(const ValueKey('device_blocked_unlink')));
      await tester.pump();
      expect(auth.signOutCalls, 1);
    });
  });
}
