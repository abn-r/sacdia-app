import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/notifications/push_notification_provider.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
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
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/teen/presentation/views/teen_pending_home_view.dart';
import 'package:sacdia_app/features/teen/domain/entities/teen_supervision.dart';
import 'package:sacdia_app/features/teen/domain/repositories/teen_repository.dart';
import 'package:sacdia_app/features/teen/presentation/providers/teen_providers.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:dartz/dartz.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show
        FakeNotificationsRepository,
        FakePushNotificationService,
        FakeSecureStorage;
import '../family/family_test_harness.dart';
import '../../support/riverpod_test_support.dart';

/// Un alta nueva con Google/Apple no trae fecha de nacimiento (modo
/// `profile_incomplete`). Al guardar el paso 2 el cliente vuelve a pedir
/// `/auth/me` y el servidor la reclasifica; el router REAL sigue ese cambio.

const _authz = AuthorizationSnapshot(effectivePermissions: ['clubs:read']);

const _unknownAge = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  name: 'Ana',
  postRegisterComplete: false,
  principal: PrincipalInfo(kind: PrincipalKind.ageUnknownUser),
  serverMode: AccountMode.profileIncomplete,
  authorization: _authz,
);

const _minorAfterStep2 = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  name: 'Ana',
  postRegisterComplete: false,
  principal: PrincipalInfo(
    kind: PrincipalKind.supervisedUser,
    supervision: SupervisionInfo(status: SupervisionStatus.pendingGuardian),
  ),
  serverMode: AccountMode.teenPending,
  authorization: _authz,
);

const _adultAfterStep2 = UserEntity(
  id: 'u1',
  email: 'u1@example.com',
  name: 'Ana',
  postRegisterComplete: false,
  principal: PrincipalInfo(kind: PrincipalKind.user),
  serverMode: AccountMode.adult,
  authorization: _authz,
);

class _Auth extends AuthNotifier {
  _Auth({required this.afterStep2});

  /// Lo que `/auth/me` devuelve tras guardar el paso 2 (y después).
  UserEntity afterStep2;
  int refreshes = 0;

  @override
  Future<UserEntity?> build() async => _unknownAge;

  @override
  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async {
    refreshes++;
    // Tras el paso 3 el servidor ya declara el post-registro completo.
    final current = state.valueOrNull;
    final next = (current?.postRegisterComplete ?? false)
        ? UserEntity(
            id: afterStep2.id,
            email: afterStep2.email,
            name: afterStep2.name,
            postRegisterComplete: true,
            principal: afterStep2.principal,
            serverMode: afterStep2.serverMode,
            authorization: afterStep2.authorization,
          )
        : afterStep2;
    state = AsyncValue.data(next);
    return next;
  }

  @override
  Future<bool> refreshSupervision({Duration? minInterval}) async => false;
}

/// El provider es autoDispose y se reconstruye: los contadores viven fuera.
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

class _Step2Status extends CompletionStatusNotifier {
  @override
  Future<CompletionStatus?> build() async => const CompletionStatus(
        isComplete: false,
        currentStep: 2,
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

class _TeenRepo implements TeenRepository {
  @override
  Future<Either<Failure, TeenSupervision>> getSupervision() async =>
      const Right(TeenSupervision(status: SupervisionStatus.pendingGuardian));

  @override
  Future<Either<Failure, TeenLinkCode>> issueLinkCode() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> revokePendingLink(String id) =>
      throw UnimplementedError();
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
    WidgetTester tester,
    UserEntity afterStep2,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = _Auth(afterStep2: afterStep2);
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
        completionStatusProvider.overrideWith(_Step2Status.new),
        canCompleteStep2Provider.overrideWithValue(true),
        canCompleteStep3Provider.overrideWithValue(true),
        personalInfoSnapshotProvider.overrideWith((ref) async => null),
        emergencyContactsProvider.overrideWith(_EmptyContacts.new),
        countriesProvider.overrideWith((ref) async => const []),
        teenRepositoryProvider.overrideWithValue(_TeenRepo()),
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
      'saving step 2 refetches /auth/me; a minor finishes on the pending-teen '
      'screen', (tester) async {
    final h = await mount(tester, _minorAfterStep2);
    expect(where(h.router), RouteNames.postRegistration);
    expect(h.auth.refreshes, 0);

    await tester.tap(find.text('Continuar'));
    await _settle(tester);

    expect(h.flow.step2Calls, 1);
    expect(h.auth.refreshes, 1, reason: 'step 2 must refetch /auth/me');
    expect(
      h.auth.state.valueOrNull!.mode,
      AccountMode.teenPending,
      reason: 'the mode follows the server right after the birthday is saved',
    );
    // Sigue en el post-registro (la whitelist del menor lo permite) y avanzó.
    expect(where(h.router), RouteNames.postRegistration);
    expect(find.text('Finalizar'), findsOneWidget);

    await tester.tap(find.text('Finalizar'));
    await _settle(tester);

    expect(h.flow.step3Calls, 1);
    expect(where(h.router), RouteNames.teenPendingHome);
    expect(find.byType(TeenPendingHomeView), findsOneWidget);
  });

  testWidgets('an adult keeps the post-registration and finishes at home',
      (tester) async {
    final h = await mount(tester, _adultAfterStep2);

    await tester.tap(find.text('Continuar'));
    await _settle(tester);

    expect(h.auth.refreshes, 1);
    expect(h.auth.state.valueOrNull!.mode, AccountMode.adult);
    expect(where(h.router), RouteNames.postRegistration);

    await tester.tap(find.text('Finalizar'));
    await _settle(tester);

    expect(where(h.router), RouteNames.homeDashboard);
  });

  testWidgets(
      'if /auth/me still says profile_incomplete after step 2 the flow does '
      'not advance', (tester) async {
    final h = await mount(tester, _unknownAge);

    await tester.tap(find.text('Continuar'));
    await _settle(tester);

    expect(h.flow.step2Calls, 1);
    expect(h.auth.refreshes, 1);
    expect(find.text('Finalizar'), findsNothing);
    expect(where(h.router), RouteNames.postRegistration);
  });
}
