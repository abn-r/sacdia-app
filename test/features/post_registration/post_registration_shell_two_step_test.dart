import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_flow_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/club_selection_step_view.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show
        FakeNotificationsRepository,
        FakePushNotificationService,
        FakeSecureStorage;
import '../family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';

/// R2.2, R2.8, S2.1, S2.9: una cuenta `club_exempt` recorre 2 pasos; al
/// guardar el paso 2 la app vuelve a pedir el usuario y solo sale al inicio si
/// el SERVIDOR ya lo marcó completo. Las demás cuentas siguen con 3 pasos.

const _authz = AuthorizationSnapshot(effectivePermissions: ['clubs:read']);

UserEntity _user({
  required OnboardingMode mode,
  bool complete = false,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      name: 'Ana',
      postRegisterComplete: complete,
      onboardingMode: mode,
      authorization: _authz,
    );

class _Auth extends AuthNotifier {
  _Auth({required this.initial, required this.afterStep2});

  final UserEntity initial;

  /// Lo que `/auth/me` devuelve tras guardar el paso 2.
  final UserEntity afterStep2;
  int refreshes = 0;

  @override
  Future<UserEntity?> build() async => initial;

  @override
  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async {
    refreshes++;
    state = AsyncValue.data(afterStep2);
    return afterStep2;
  }

  @override
  Future<bool> refreshSupervision({Duration? minInterval}) async => false;
}

class _FlowCalls {
  int step2Calls = 0;
  int step3Calls = 0;
}

class _Flow extends PostRegistrationFlowNotifier {
  _Flow(this.calls);

  final _FlowCalls calls;

  @override
  Future<PostRegistrationFlowResult> completeStep2({
    required bool canReadSensitiveData,
  }) async {
    calls.step2Calls++;
    return const PostRegistrationFlowResult.success();
  }

  @override
  Future<PostRegistrationFlowResult> completeStep3() async {
    calls.step3Calls++;
    return const PostRegistrationFlowResult.success();
  }
}

/// El servidor devuelve `currentStep` según su `nextStep`; para `club_exempt`
/// no existe un paso 3, así que un valor 3 debe quedar acotado a 2.
class _Status extends CompletionStatusNotifier {
  _Status(this.step);

  final int step;

  @override
  Future<CompletionStatus?> build() async => CompletionStatus(
        isComplete: false,
        currentStep: step,
        photoComplete: true,
        personalInfoComplete: false,
        clubSelectionComplete: false,
      );
}

class _Ready extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
}

class _NullDashboard extends DashboardNotifier {
  @override
  Future<DashboardSummary?> build() async => null;
}

class _NullProfile extends ProfileNotifier {
  @override
  Future<UserDetail?> build() async => null;
}

class _EmptyContacts extends EmergencyContactsNotifier {
  @override
  Future<List<EmergencyContactModel>> build() async => const [];
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  Future<({_Auth auth, _FlowCalls flow, dynamic router})> mount(
    WidgetTester tester, {
    required UserEntity initial,
    required UserEntity afterStep2,
    int serverStep = 2,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = _Auth(initial: initial, afterStep2: afterStep2);
    final flow = _FlowCalls();
    final c = createTestContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        pushNotificationServiceProvider.overrideWith(
          (ref) => FakePushNotificationService(ref: ref, prefs: prefs),
        ),
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_Ready.new),
        postRegistrationFlowNotifierProvider.overrideWith(() => _Flow(flow)),
        completionStatusProvider.overrideWith(() => _Status(serverStep)),
        canCompleteStep2Provider.overrideWithValue(true),
        canCompleteStep3Provider.overrideWithValue(true),
        personalInfoSnapshotProvider.overrideWith((ref) async => null),
        emergencyContactsProvider.overrideWith(_EmptyContacts.new),
        countriesProvider.overrideWith((ref) async => const []),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        notificationsRepositoryProvider
            .overrideWithValue(FakeNotificationsRepository()),
      ],
    );
    addTearDown(() {
      c.read(routerProvider).dispose();
    });
    await c.read(authNotifierProvider.future);
    final router = c.read(routerProvider);
    await pumpLocalizedRouterApp(tester, c, router);
    await _settle(tester);
    return (auth: auth, flow: flow, router: router);
  }

  String where(dynamic router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation as String;

  testWidgets(
      'club_exempt: counter says 2, step 2 is the last one and there is no '
      'club page', (tester) async {
    final user = _user(mode: OnboardingMode.clubExempt);
    await mount(tester, initial: user, afterStep2: user, serverStep: 3);

    // El 3 que mandó el servidor se acota a 2.
    expect(find.text('2 de 2'), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(find.text('Continuar'), findsNothing);
    expect(find.byType(ClubSelectionStepView), findsNothing);
  });

  testWidgets(
      'club_exempt: after step 2 the refreshed user is complete -> home, and '
      'step 3 is never called', (tester) async {
    final h = await mount(
      tester,
      initial: _user(mode: OnboardingMode.clubExempt),
      afterStep2: _user(mode: OnboardingMode.clubExempt, complete: true),
    );

    await tester.tap(find.text('Finalizar'));
    await _settle(tester);

    expect(h.flow.step2Calls, 1);
    expect(h.flow.step3Calls, 0);
    expect(h.auth.refreshes, 1);
    expect(h.auth.state.value!.postRegisterComplete, isTrue);
    expect(where(h.router), RouteNames.homeDashboard);
  });

  testWidgets(
      'club_exempt: if the server did not complete it the shell stays and '
      'shows the error', (tester) async {
    final user = _user(mode: OnboardingMode.clubExempt);
    final h = await mount(tester, initial: user, afterStep2: user);

    await tester.tap(find.text('Finalizar'));
    await _settle(tester);

    expect(h.flow.step2Calls, 1);
    expect(h.auth.refreshes, 1);
    expect(h.flow.step3Calls, 0);
    expect(h.auth.state.value!.postRegisterComplete, isFalse);
    expect(where(h.router), RouteNames.postRegistration);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets(
      'club mode keeps 3 steps: step 2 advances to the club step and the '
      'counter says 3', (tester) async {
    final user = _user(mode: OnboardingMode.club);
    final h = await mount(tester, initial: user, afterStep2: user);

    expect(find.text('2 de 3'), findsOneWidget);
    expect(find.text('Continuar'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await _settle(tester);

    expect(h.flow.step2Calls, 1);
    expect(find.text('3 de 3'), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(find.byType(ClubSelectionStepView), findsOneWidget);
    expect(where(h.router), RouteNames.postRegistration);
  });
}
