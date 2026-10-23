import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/errors/exceptions.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/post_registration/data/datasources/club_selection_remote_data_source.dart';
import 'package:sacdia_app/features/post_registration/data/models/class_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/club_section_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/country_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/local_field_model.dart';
import 'package:sacdia_app/features/post_registration/data/models/union_model.dart';
import 'package:sacdia_app/features/post_registration/presentation/providers/club_selection_providers.dart';
import 'package:sacdia_app/features/post_registration/presentation/views/club_selection_step_view.dart';
import 'package:sacdia_app/features/post_registration/presentation/widgets/guardian_only_exit.dart';

import '../family/family_test_harness.dart';

class _FakeClubDataSource implements ClubSelectionRemoteDataSource {
  _FakeClubDataSource({this.guardianOnlyError});

  final AppException? guardianOnlyError;
  final guardianOnlyCalls = <String>[];

  @override
  Future<void> completeGuardianOnly({
    required String userId,
    int? countryId,
    int? unionId,
    int? localFieldId,
  }) async {
    guardianOnlyCalls.add(userId);
    if (guardianOnlyError != null) throw guardianOnlyError!;
  }

  @override
  Future<List<CountryModel>> getCountries({CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<List<UnionModel>> getUnionsByCountry(int countryId,
          {CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<List<LocalFieldModel>> getLocalFieldsByUnion(int unionId,
          {CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<List<ClubModel>> getClubsByLocalField(int localFieldId,
          {CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<List<ClubSectionModel>> getClubSections(int clubId,
          {CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<List<ClassModel>> getClassesByClubType(int clubTypeId,
          {CancelToken? cancelToken}) async =>
      const [];

  @override
  Future<void> completeStep3({
    required String userId,
    required int countryId,
    required int unionId,
    required int localFieldId,
    required int clubSectionId,
    int? classId,
  }) async {}
}

class _RecordingAuth extends FakeAuthNotifier {
  _RecordingAuth([super.user]);

  int markCalls = 0;
  int refreshCalls = 0;
  String? lastMarkedFor;

  @override
  void markPostRegisterComplete({String? forUserId}) {
    markCalls++;
    lastMarkedFor = forUserId;
  }

  @override
  Future<UserEntity?> refreshCurrentUser({
    bool keepCurrentOnFailure = false,
  }) async {
    refreshCalls++;
    return user;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initLocalization);

  const incompleteGuardian = UserEntity(
    id: 'guardian-1',
    email: 'maria@example.com',
    name: 'María',
    postRegisterComplete: false,
  );

  Future<GoRouter> pump(
    WidgetTester tester, {
    required _RecordingAuth auth,
    required _FakeClubDataSource ds,
    ActingForSession? session,
    Widget child = const Scaffold(
        body: SingleChildScrollView(
      child: GuardianOnlyExit(),
    )),
  }) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return pumpFamilyApp(
      tester,
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        clubSelectionDataSourceProvider.overrideWithValue(ds),
        if (session != null)
          actingForSessionProvider.overrideWithValue(session),
      ],
      routes: [
        GoRoute(path: '/', builder: (_, __) => child),
        stubRoute(RouteNames.homeDashboard),
        stubRoute(RouteNames.family),
      ],
    );
  }

  testWidgets('shows the exit for the guardian and confirms before calling',
      (tester) async {
    final auth = _RecordingAuth(incompleteGuardian);
    final ds = _FakeClubDataSource();
    await pump(tester, auth: auth, ds: ds);

    expect(find.text('Solo soy tutor de menores'), findsOneWidget);

    await tester
        .tap(find.widgetWithText(SacButton, 'Solo soy tutor de menores'));
    await tester.pumpAndSettle();
    expect(find.text('¿Terminar tu registro como tutor?'), findsOneWidget);
    // Cancelar no llama al backend.
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(ds.guardianOnlyCalls, isEmpty);
    expect(auth.markCalls, 0);
  });

  testWidgets('success completes post-registration and opens Mi familia',
      (tester) async {
    final auth = _RecordingAuth(incompleteGuardian);
    final ds = _FakeClubDataSource();
    final router = await pump(tester, auth: auth, ds: ds);

    await tester
        .tap(find.widgetWithText(SacButton, 'Solo soy tutor de menores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminar registro'));
    await tester.pumpAndSettle();

    expect(ds.guardianOnlyCalls, ['guardian-1']);
    expect(auth.markCalls, 1);
    expect(
      auth.lastMarkedFor,
      'guardian-1',
      reason: 'the mark is scoped to the user that started the exit (S1)',
    );
    expect(auth.refreshCalls, 1);
    expect(router.state.uri.path, RouteNames.family);
    expect(find.text('route:${RouteNames.family}'), findsOneWidget);

    // Atrás desde Mi familia vuelve al inicio, no sale de la app.
    router.pop();
    await tester.pumpAndSettle();
    expect(router.state.uri.path, RouteNames.homeDashboard);
  });

  testWidgets('a minor gets the translated 422 and stays in the flow',
      (tester) async {
    final auth = _RecordingAuth(incompleteGuardian);
    final ds = _FakeClubDataSource(
      guardianOnlyError: ServerException(
        message: 'x',
        code: 422,
        errorCode: 'POST_REG_GUARDIAN_ONLY_REQUIRES_ADULT',
      ),
    );
    final router = await pump(tester, auth: auth, ds: ds);

    await tester
        .tap(find.widgetWithText(SacButton, 'Solo soy tutor de menores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminar registro'));
    await tester.pumpAndSettle();

    expect(
      find.text(
          'Solo una persona mayor de edad puede registrarse solo como tutor.'),
      findsOneWidget,
    );
    expect(auth.markCalls, 0);
    expect(router.state.uri.path, '/');
  });

  testWidgets('an unknown failure shows the generic message', (tester) async {
    final auth = _RecordingAuth(incompleteGuardian);
    final ds = _FakeClubDataSource(
      guardianOnlyError: ServerException(message: 'raw server text', code: 500),
    );
    await pump(tester, auth: auth, ds: ds);

    await tester
        .tap(find.widgetWithText(SacButton, 'Solo soy tutor de menores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Terminar registro'));
    await tester.pumpAndSettle();

    expect(
      find.text('No pudimos terminar tu registro. Intenta de nuevo.'),
      findsOneWidget,
    );
    expect(find.text('raw server text'), findsNothing);
    expect(auth.markCalls, 0);
  });

  group('is hidden for any principal that is not an adult', () {
    UserEntity user({
      required PrincipalInfo principal,
      AccountMode? mode,
    }) =>
        UserEntity(
          id: 'u-1',
          postRegisterComplete: false,
          principal: principal,
          serverMode: mode,
        );

    const teenPending = PrincipalInfo(
      kind: PrincipalKind.supervisedUser,
      supervision: SupervisionInfo(status: SupervisionStatus.pendingGuardian),
    );
    const teenActive = PrincipalInfo(
      kind: PrincipalKind.supervisedUser,
      supervision: SupervisionInfo(status: SupervisionStatus.active),
    );

    final cases = <String, UserEntity>{
      'teen_pending':
          user(principal: teenPending, mode: AccountMode.teenPending),
      'teen_supervised':
          user(principal: teenActive, mode: AccountMode.teenSupervised),
      'profile_incomplete': user(
        principal: const PrincipalInfo(kind: PrincipalKind.ageUnknownUser),
        mode: AccountMode.profileIncomplete,
      ),
      'unknown principal':
          user(principal: const PrincipalInfo(kind: PrincipalKind.unknown)),
      'a non-user kind even if the mode says adult': user(
        principal: const PrincipalInfo(kind: PrincipalKind.linkedDevice),
        mode: AccountMode.adult,
      ),
    };

    for (final entry in cases.entries) {
      testWidgets(entry.key, (tester) async {
        await pump(
          tester,
          auth: _RecordingAuth(entry.value),
          ds: _FakeClubDataSource(),
        );

        expect(find.text('Solo soy tutor de menores'), findsNothing);
        expect(find.byType(SacButton), findsNothing);
      });
    }

    testWidgets('an adult with the user principal still sees it',
        (tester) async {
      await pump(
        tester,
        auth: _RecordingAuth(user(
          principal: const PrincipalInfo(kind: PrincipalKind.user),
          mode: AccountMode.adult,
        )),
        ds: _FakeClubDataSource(),
      );

      expect(find.text('Solo soy tutor de menores'), findsOneWidget);
    });
  });

  testWidgets('is hidden while acting for a dependent (session)',
      (tester) async {
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    await pump(
      tester,
      auth: _RecordingAuth(incompleteGuardian),
      ds: _FakeClubDataSource(),
      session: session,
    );

    expect(find.text('Solo soy tutor de menores'), findsNothing);
    expect(find.byType(SacButton), findsNothing);
  });

  testWidgets('is hidden when the loaded user is a dependent (actingFor)',
      (tester) async {
    await pump(
      tester,
      auth: _RecordingAuth(
        const UserEntity(
          id: 'ana-1',
          name: 'Ana',
          actingFor: ActingForInfo(
            actorUserId: 'guardian-1',
            dependentUserId: 'ana-1',
          ),
        ),
      ),
      ds: _FakeClubDataSource(),
    );

    expect(find.text('Solo soy tutor de menores'), findsNothing);
  });

  group('ClubSelectionStepView', () {
    Future<void> pumpStep(
      WidgetTester tester, {
      required bool isClubTransfer,
      ActingForSession? session,
    }) async {
      await pump(
        tester,
        auth: _RecordingAuth(incompleteGuardian),
        ds: _FakeClubDataSource(),
        session: session,
        child: Scaffold(
          body: ClubSelectionStepView(isClubTransfer: isClubTransfer),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers the exit in post-registration step 3', (tester) async {
      await pumpStep(tester, isClubTransfer: false);

      expect(find.text('Solo soy tutor de menores'), findsOneWidget);
    });

    testWidgets('does not offer it for a club transfer', (tester) async {
      await pumpStep(tester, isClubTransfer: true);

      expect(find.text('Solo soy tutor de menores'), findsNothing);
    });

    testWidgets('does not offer it while acting', (tester) async {
      final session = ActingForSession()
        ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
      await pumpStep(tester, isClubTransfer: false, session: session);

      expect(find.text('Solo soy tutor de menores'), findsNothing);
    });

    group('consent form upload while acting (FP3-27)', () {
      const actingUser = UserEntity(
        id: 'ana-1',
        name: 'Ana',
        postRegisterComplete: false,
        actingFor: ActingForInfo(
          actorUserId: 'guardian-1',
          dependentUserId: 'ana-1',
          consentStatus: 'pending',
          scopes: ['self:read', 'registration:write', 'consent:evidence'],
        ),
      );

      Future<void> pumpActing(
        WidgetTester tester, {
        required bool isClubTransfer,
        UserEntity user = actingUser,
      }) async {
        final session = ActingForSession()
          ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
        await pump(
          tester,
          auth: _RecordingAuth(user),
          ds: _FakeClubDataSource(),
          session: session,
          child: Scaffold(
            body: ClubSelectionStepView(isClubTransfer: isClubTransfer),
          ),
        );
        await tester.pumpAndSettle();
      }

      const card = ValueKey('acting_consent_form_card');

      testWidgets('step 3 offers the form while acting with the scope',
          (tester) async {
        await pumpActing(tester, isClubTransfer: false);
        await tester.scrollUntilVisible(
          find.byKey(card),
          300,
          scrollable: find.byType(Scrollable).first,
        );

        expect(find.byKey(card), findsOneWidget);
      });

      testWidgets('not for a club transfer', (tester) async {
        await pumpActing(tester, isClubTransfer: true);
        expect(find.byKey(card), findsNothing);
      });

      testWidgets('not without the server scope', (tester) async {
        await pumpActing(
          tester,
          isClubTransfer: false,
          user: const UserEntity(
            id: 'ana-1',
            postRegisterComplete: false,
            actingFor: ActingForInfo(
              actorUserId: 'guardian-1',
              dependentUserId: 'ana-1',
              consentStatus: 'pending',
              scopes: ['self:read'],
            ),
          ),
        );
        expect(find.byKey(card), findsNothing);
      });

      testWidgets('not when the guardian is not acting', (tester) async {
        await pumpStep(tester, isClubTransfer: false);
        expect(find.byKey(card), findsNothing);
      });
    });
  });
}
