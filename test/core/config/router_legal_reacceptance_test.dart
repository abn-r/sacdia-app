import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/auth/acting_for_session.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/errors/failures.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_document.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:sacdia_app/features/legal/domain/entities/legal_status.dart';
import 'package:sacdia_app/features/legal/domain/repositories/legal_repository.dart';
import 'package:sacdia_app/features/legal/presentation/providers/legal_providers.dart';
import 'package:sacdia_app/features/legal/presentation/views/legal_acceptance_view.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:sacdia_app/features/teen/domain/entities/teen_supervision.dart';
import 'package:sacdia_app/features/teen/domain/repositories/teen_repository.dart';
import 'package:sacdia_app/features/teen/presentation/providers/teen_providers.dart';
import 'package:sacdia_app/features/teen/presentation/views/teen_pending_home_view.dart';

import '../../features/auth/presentation/providers/auth_notifier_test_support.dart'
    show FakeNotificationsRepository;
import '../../features/family/family_test_harness.dart';

/// FP3-28: tras subir la versión de Términos y Privacidad TODOS pasan por un
/// gate duro: el adulto, el adolescente pendiente de tutor y el tutor que
/// actúa por un menor (que acepta en nombre del menor). Estas pruebas usan el
/// router REAL y la vista REAL del gate.

const _versionTerms = '2.0.0-family';

LegalStatus _status() => LegalStatus(
      requiresAcceptance: true,
      documents: [
        LegalDocumentStatus(
          documentType: LegalDocumentTypes.terms,
          version: _versionTerms,
          url: 'https://sacdia.com/terms',
          accepted: false,
        ),
        LegalDocumentStatus(
          documentType: LegalDocumentTypes.privacy,
          version: _versionTerms,
          url: 'https://sacdia.com/privacy',
          accepted: false,
        ),
      ],
    );

class _Legal implements LegalRepository {
  Either<Failure, LegalStatus> acceptResult = Right(_status());
  int statusCalls = 0;
  final sent = <({String terms, String privacy})>[];

  @override
  Future<Either<Failure, LegalStatus>> getMyStatus() async {
    statusCalls++;
    return Right(_status());
  }

  @override
  Future<Either<Failure, LegalStatus>> accept({
    required String termsVersion,
    required String privacyVersion,
  }) async {
    sent.add((terms: termsVersion, privacy: privacyVersion));
    return acceptResult;
  }

  @override
  Future<Either<Failure, List<LegalDocument>>> getCurrentDocuments() async =>
      const Right([]);
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

/// El `markLegalAccepted` REAL baja la bandera en memoria; el resto se evita.
class _Auth extends AuthNotifier {
  _Auth(this.user);

  final UserEntity user;
  int signOuts = 0;
  final switches = <String?>[];

  @override
  Future<UserEntity?> build() async => user;

  @override
  Future<bool> signOut() async {
    signOuts++;
    return true;
  }

  @override
  Future<SwitchProfileOutcome> switchProfile(
    String? dependentId, {
    String? firstName,
  }) async {
    switches.add(dependentId);
    return SwitchProfileOutcome.exited;
  }

  @override
  Future<bool> refreshSupervision({Duration? minInterval}) async => false;
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

UserEntity _user({
  AccountMode? mode,
  String id = 'u1',
  bool postRegisterComplete = true,
}) =>
    UserEntity(
      id: id,
      email: '$id@example.com',
      name: 'Ana',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: true,
      serverMode: mode,
      authorization: const AuthorizationSnapshot(
        effectivePermissions: ['clubs:read'],
      ),
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(initLocalization);

  late _Legal legal;

  Future<({ProviderContainer c, _Auth auth, dynamic router})> mount(
    WidgetTester tester,
    UserEntity user, {
    ActingForSession? session,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    legal = _Legal();
    final auth = _Auth(user);
    final c = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(() => auth),
        appBootstrapProvider.overrideWith(_Ready.new),
        legalRepositoryProvider.overrideWithValue(legal),
        teenRepositoryProvider.overrideWithValue(_TeenRepo()),
        dashboardNotifierProvider.overrideWith(_NullDashboard.new),
        profileNotifierProvider.overrideWith(_NullProfile.new),
        notificationsRepositoryOverride,
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
    return (c: c, auth: auth, router: router);
  }

  String where(dynamic router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation as String;

  Future<void> accept(WidgetTester tester) async {
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Aceptar y continuar'));
    await tester.pump();
    await _settle(tester);
  }

  testWidgets('an adult lands on the gate and cannot navigate around it',
      (tester) async {
    final h = await mount(tester, _user());

    expect(where(h.router), RouteNames.legalAcceptance);
    expect(find.byType(LegalAcceptanceView), findsOneWidget);
    expect(find.text('Versión $_versionTerms'), findsNWidgets(2));

    // Cualquier destino rebota al gate (gate duro).
    h.router.go(RouteNames.homeDashboard);
    await _settle(tester);
    expect(where(h.router), RouteNames.legalAcceptance);
    h.router.go(RouteNames.family);
    await _settle(tester);
    expect(where(h.router), RouteNames.legalAcceptance);

    await accept(tester);

    expect(legal.sent, [(terms: _versionTerms, privacy: _versionTerms)]);
    expect(where(h.router), RouteNames.homeDashboard);
  });

  testWidgets(
      'a pending teen reaches the gate, accepts for themselves and '
      'goes to the status screen', (tester) async {
    final h = await mount(tester, _user(mode: AccountMode.teenPending));

    expect(where(h.router), RouteNames.legalAcceptance);
    // El adolescente pendiente no puede saltarse el gate.
    h.router.go(RouteNames.teenPendingHome);
    await _settle(tester);
    expect(where(h.router), RouteNames.legalAcceptance);

    await accept(tester);

    expect(legal.sent, hasLength(1));
    expect(where(h.router), RouteNames.teenPendingHome);
    expect(find.byType(TeenPendingHomeView), findsOneWidget);
  });

  testWidgets('a verified teen goes home after accepting', (tester) async {
    final h = await mount(tester, _user(mode: AccountMode.teenSupervised));

    await accept(tester);

    expect(where(h.router), RouteNames.homeDashboard);
  });

  testWidgets(
      'a guardian acting for a minor accepts for the minor, and the '
      'gate offers going back instead of signing out', (tester) async {
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    final h = await mount(tester, _user(id: 'ana-1'), session: session);

    expect(where(h.router), RouteNames.legalAcceptance);
    expect(find.text('Cerrar sesión'), findsNothing);
    expect(find.text('Volver a mi perfil'), findsOneWidget);

    await accept(tester);

    // Se aceptó UNA vez, para el perfil que se ve (el menor).
    expect(legal.sent, hasLength(1));
    expect(where(h.router), RouteNames.homeDashboard);
    expect(h.auth.signOuts, 0);
  });

  testWidgets('the acting gate can return to the guardian profile',
      (tester) async {
    final session = ActingForSession()
      ..enter(const ActingDependent(userId: 'ana-1', firstName: 'Ana'));
    final h = await mount(tester, _user(id: 'ana-1'), session: session);

    await tester.tap(find.text('Volver a mi perfil'));
    await tester.pump();

    expect(h.auth.switches, [null]);
    expect(h.auth.signOuts, 0);
  });

  testWidgets('signing out from the gate is available to a non-acting user',
      (tester) async {
    final h = await mount(tester, _user(mode: AccountMode.teenPending));

    await tester.tap(find.text('Cerrar sesión'));
    await tester.pump();

    expect(h.auth.signOuts, 1);
  });

  testWidgets('a stale version sent refreshes the documents and explains',
      (tester) async {
    final h = await mount(tester, _user());
    legal.acceptResult = const Left(
      ServerFailure(
        message: 'RAW',
        code: 400,
        errorCode: 'LEGAL_VERSION_MISMATCH',
      ),
    );
    final before = legal.statusCalls;

    await accept(tester);

    expect(legal.statusCalls, greaterThan(before));
    expect(where(h.router), RouteNames.legalAcceptance);
    expect(
      find.text(
        'Los documentos legales se actualizaron. Revisa y acepta la versión '
        'vigente.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('RAW'), findsNothing);
  });
}

final notificationsRepositoryOverride = notificationsRepositoryProvider
    .overrideWithValue(FakeNotificationsRepository());
