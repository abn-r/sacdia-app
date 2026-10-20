import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/auth/social_credential.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/delete_account_reauth.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/family/domain/entities/dependent.dart';
import 'package:sacdia_app/features/family/presentation/providers/family_providers.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'package:sacdia_app/features/post_registration/domain/entities/completion_status.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/personal_info_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/post_registration_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/profile/presentation/widgets/delete_account_confirm_dialog.dart';
import 'package:sacdia_app/features/teen/domain/entities/teen_supervision.dart';
import 'package:sacdia_app/features/teen/domain/repositories/teen_repository.dart';
import 'package:sacdia_app/features/teen/presentation/providers/teen_providers.dart';
import 'package:sacdia_app/providers/storage_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository, FakeSecureStorage;
import '../family/family_test_harness.dart';

/// App Store 5.1.1(v): quien se registra con Apple/Google (`age_unknown_user`)
/// debe poder borrar su cuenta desde el post-registro. Router y shell REALES.

const _authz = AuthorizationSnapshot(effectivePermissions: ['clubs:read']);

UserEntity _user(
  PrincipalInfo principal,
  AccountMode mode, {
  ActingForInfo? actingFor,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      name: 'Ana',
      postRegisterComplete: false,
      principal: principal,
      serverMode: mode,
      actingFor: actingFor,
      authorization: _authz,
    );

final _ageUnknown = _user(
  const PrincipalInfo(kind: PrincipalKind.ageUnknownUser),
  AccountMode.profileIncomplete,
);
final _adult = _user(
  const PrincipalInfo(kind: PrincipalKind.user),
  AccountMode.adult,
);
final _teenPending = _user(
  const PrincipalInfo(
    kind: PrincipalKind.supervisedUser,
    supervision: SupervisionInfo(status: SupervisionStatus.pendingGuardian),
  ),
  AccountMode.teenPending,
);
final _teenSupervised = _user(
  const PrincipalInfo(
    kind: PrincipalKind.supervisedUser,
    supervision: SupervisionInfo(status: SupervisionStatus.active),
  ),
  AccountMode.teenSupervised,
);

class _Auth extends AuthNotifier {
  _Auth(this.user);

  final UserEntity user;
  final deletes = <DeleteAccountReauth>[];

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<DeleteAccountResult> deleteAccountWithResult(
    DeleteAccountReauth reauth,
  ) async {
    deletes.add(reauth);
    state = const AsyncValue.data(null);
    return const DeleteAccountResult.success();
  }

  @override
  Future<List<SocialProvider>> connectedProviders() async => const [];

  @override
  Future<bool> refreshSupervision({Duration? minInterval}) async => false;
}

class _Ready extends AppBootstrapNotifier {
  @override
  Future<AppBootstrapState> build() async => const AppBootstrapReady();
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

  final deleteButton = find.byKey(
    const ValueKey('post_registration_delete_account'),
  );

  Future<({_Auth auth, dynamic router})> mount(
    WidgetTester tester,
    UserEntity user, {
    ActingForSession? session,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = _Auth(user);
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(FakeSecureStorage()),
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_Ready.new),
        completionStatusProvider.overrideWith(_Step2Status.new),
        personalInfoSnapshotProvider.overrideWith((ref) async => null),
        emergencyContactsProvider.overrideWith(_EmptyContacts.new),
        deletionImpactProvider
            .overrideWith((ref) async => const <DeletionImpactEntry>[]),
        teenRepositoryProvider.overrideWithValue(_TeenRepo()),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        notificationsRepositoryProvider
            .overrideWithValue(FakeNotificationsRepository()),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
    );
    addTearDown(() {
      c.read(routerProvider).dispose();
      c.dispose();
    });
    await c.read(authNotifierProvider.future);
    final router = c.read(routerProvider);
    await pumpLocalizedRouterApp(tester, c, router);
    await _settle(tester);
    return (auth: auth, router: router);
  }

  String where(dynamic router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation as String;

  testWidgets(
      'a new Apple/Google sign-up (age_unknown_user) can delete the account '
      'from post-registration', (tester) async {
    final h = await mount(tester, _ageUnknown);
    expect(where(h.router), RouteNames.postRegistration);
    expect(deleteButton, findsOneWidget);

    await tester.tap(deleteButton);
    await _settle(tester);
    // Primera confirmación.
    expect(find.text('Eliminar cuenta'), findsWidgets);
    await tester.tap(find.text('Continuar').last);
    await _settle(tester);

    // Segunda: palabra de confirmación + contraseña.
    expect(find.byType(DeleteAccountConfirmDialog), findsOneWidget);
    final fields = find.descendant(
      of: find.byType(DeleteAccountConfirmDialog),
      matching: find.byType(TextField),
    );
    await tester.enterText(fields.at(0), 'ELIMINAR');
    await tester.enterText(fields.at(1), 'Password123');
    await tester.pump();
    await tester.tap(find.text('Eliminar cuenta').last);
    await _settle(tester);

    expect(h.auth.deletes, hasLength(1));
    expect(h.auth.deletes.single, isA<PasswordReauth>());
    // La sesión terminó: el router lleva fuera del post-registro.
    expect(where(h.router), isNot(RouteNames.postRegistration));
    expect(h.auth.state.valueOrNull, isNull);
  });

  testWidgets('cancelling the first confirmation deletes nothing',
      (tester) async {
    final h = await mount(tester, _ageUnknown);

    await tester.tap(deleteButton);
    await _settle(tester);
    await tester.tap(find.text('Cancelar').last);
    await _settle(tester);

    expect(h.auth.deletes, isEmpty);
    expect(where(h.router), RouteNames.postRegistration);
  });

  testWidgets('an adult in post-registration sees it too', (tester) async {
    await mount(tester, _adult);
    expect(deleteButton, findsOneWidget);
  });

  testWidgets('a pending teen does not see it', (tester) async {
    final h = await mount(tester, _teenPending);
    expect(where(h.router), RouteNames.postRegistration);
    expect(deleteButton, findsNothing);
    // El cierre de sesión sigue disponible.
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
  });

  testWidgets('a teen with a verified guardian does not see it',
      (tester) async {
    final h = await mount(tester, _teenSupervised);
    expect(where(h.router), RouteNames.postRegistration);
    expect(deleteButton, findsNothing);
  });

  testWidgets('it is never offered while acting for a dependent',
      (tester) async {
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'u1', firstName: 'Ana'));
    final h = await mount(tester, _adult, session: session);
    expect(where(h.router), RouteNames.postRegistration);
    expect(deleteButton, findsNothing);
  });

  group('canDeleteAccountInPostRegistration', () {
    test('only an adult or a no-birthday account, never acting', () {
      expect(canDeleteAccountInPostRegistration(_ageUnknown, acting: false),
          isTrue);
      expect(canDeleteAccountInPostRegistration(_adult, acting: false), isTrue);
      expect(canDeleteAccountInPostRegistration(_adult, acting: true), isFalse);
      expect(canDeleteAccountInPostRegistration(_teenPending, acting: false),
          isFalse);
      expect(canDeleteAccountInPostRegistration(_teenSupervised, acting: false),
          isFalse);
      expect(canDeleteAccountInPostRegistration(null, acting: false), isFalse);
    });

    test('an unknown principal and a loaded dependent are excluded', () {
      expect(
        canDeleteAccountInPostRegistration(
          _user(const PrincipalInfo(kind: PrincipalKind.unknown),
              AccountMode.restricted),
          acting: false,
        ),
        isFalse,
      );
      expect(
        canDeleteAccountInPostRegistration(
          _user(
            const PrincipalInfo(kind: PrincipalKind.guardianActing),
            AccountMode.adult,
            actingFor: const ActingForInfo(
              actorUserId: 'g1',
              dependentUserId: 'u1',
            ),
          ),
          acting: false,
        ),
        isFalse,
      );
    });
  });
}
