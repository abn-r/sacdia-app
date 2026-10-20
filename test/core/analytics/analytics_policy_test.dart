import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/analytics/analytics_policy.dart';
import 'package:sacdia_app/core/config/router.dart';
import 'package:sacdia_app/core/providers/app_bootstrap_provider.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:sacdia_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:sacdia_app/features/profile/domain/entities/user_detail.dart';
import 'package:sacdia_app/features/profile/presentation/providers/profile_providers.dart';

/// Registra lo que la política le pide a la analítica real.
class _RecordingGateway implements AnalyticsGateway {
  final events = <String>[];
  String? _identified;

  @override
  bool get hasIdentifiedUser => _identified != null;

  @override
  Future<void> identify(String userId) async {
    events.add('identify:$userId');
    _identified = userId;
  }

  @override
  Future<void> reset() async {
    events.add('reset');
    _identified = null;
  }

  Iterable<String> get identifies =>
      events.where((e) => e.startsWith('identify:'));
}

UserEntity _adult(String id, {bool? anonymous = false}) => UserEntity(
      id: id,
      principal: const PrincipalInfo(kind: PrincipalKind.user),
      analyticsAnonymous: anonymous,
    );

UserEntity _teen(
  String id, {
  bool? anonymous = false,
  SupervisionStatus status = SupervisionStatus.pendingGuardian,
}) =>
    UserEntity(
      id: id,
      principal: PrincipalInfo(
        kind: PrincipalKind.supervisedUser,
        supervision: SupervisionInfo(status: status),
      ),
      // Aunque el servidor dijera `false`, un menor jamás se identifica.
      analyticsAnonymous: anonymous,
    );

void main() {
  late _RecordingGateway gateway;
  late AnalyticsPolicy policy;

  setUp(() {
    gateway = _RecordingGateway();
    policy = AnalyticsPolicy(gateway: gateway);
  });

  group('AnalyticsPolicy.apply', () {
    test('an adult with an explicit analytics_anonymous=false is identified',
        () async {
      await policy.apply(_adult('adult-1'));
      expect(gateway.events, ['identify:adult-1']);
    });

    test('an adult whose payload lacks the field stays anonymous', () async {
      await policy.apply(_adult('adult-1', anonymous: null));
      expect(gateway.events, isEmpty);
    });

    test('an adult flagged anonymous stays anonymous', () async {
      await policy.apply(_adult('adult-1', anonymous: true));
      expect(gateway.events, isEmpty);
    });

    test('a pending teen is never identified', () async {
      await policy.apply(_teen('teen-1'));
      expect(gateway.identifies, isEmpty);
    });

    test('a teen with a verified guardian is never identified', () async {
      await policy.apply(_teen('teen-1', status: SupervisionStatus.active));
      expect(gateway.identifies, isEmpty);
    });

    test('a teen flagged anonymous is never identified', () async {
      await policy.apply(_teen('teen-1', anonymous: true));
      expect(gateway.identifies, isEmpty);
    });

    test('a linked device is never identified', () async {
      await policy.apply(const UserEntity(
        id: 'kid-1',
        principal: PrincipalInfo(kind: PrincipalKind.linkedDevice),
        analyticsAnonymous: false,
      ));
      expect(gateway.identifies, isEmpty);
    });

    test('an unknown principal kind is never identified', () async {
      await policy.apply(const UserEntity(
        id: 'x',
        principal: PrincipalInfo(kind: PrincipalKind.unknown),
        analyticsAnonymous: false,
      ));
      expect(gateway.identifies, isEmpty);
    });

    test('an age-unknown user is never identified, even if the payload says so',
        () async {
      await policy.apply(const UserEntity(
        id: 'new-google',
        principal: PrincipalInfo(kind: PrincipalKind.ageUnknownUser),
        serverMode: AccountMode.profileIncomplete,
        analyticsAnonymous: false,
      ));
      expect(gateway.identifies, isEmpty);
    });

    test('an unrecognized server mode is never identified', () async {
      await policy.apply(const UserEntity(
        id: 'x',
        principal: PrincipalInfo(kind: PrincipalKind.user),
        serverMode: AccountMode.restricted,
        analyticsAnonymous: false,
      ));
      expect(gateway.identifies, isEmpty);
    });

    test('a user restored without /auth/me data is never identified', () async {
      await policy.apply(const UserEntity(id: 'cached'));
      expect(gateway.identifies, isEmpty);
    });

    test('an anonymous session resets a phone that identified someone before',
        () async {
      await policy.apply(_adult('adult-1'));
      await policy.apply(_teen('teen-1'));

      expect(gateway.events, ['identify:adult-1', 'reset']);
    });

    test('an anonymous session on a clean phone does not reset', () async {
      await policy.apply(_teen('teen-1'));
      expect(gateway.events, isEmpty);
    });

    test('adult, teen on the same phone, then another adult', () async {
      await policy.apply(_adult('adult-1'));
      await policy.apply(_teen('teen-1'));
      await policy.apply(_adult('adult-2'));

      expect(gateway.events, [
        'identify:adult-1',
        'reset',
        'identify:adult-2',
      ]);
    });

    test('no user and acting are no-ops', () async {
      await policy.apply(null);
      await policy.apply(_adult('guardian-1'), acting: true);
      await policy.apply(_teen('ana-1'), acting: true);

      expect(gateway.events, isEmpty);
    });

    test('a failing analytics backend never breaks sign-in', () async {
      final broken = AnalyticsPolicy(gateway: _ThrowingGateway());
      await expectLater(broken.apply(_adult('adult-1')), completes);
    });
  });

  group('wired through the REAL router', () {
    Future<_RecordingGateway> mount(
      WidgetTester tester,
      UserEntity? user,
    ) async {
      final recorded = _RecordingGateway();
      final container = ProviderContainer(
        overrides: [
          analyticsPolicyProvider
              .overrideWithValue(AnalyticsPolicy(gateway: recorded)),
          authNotifierProvider.overrideWith(() => _Auth(user)),
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
          dashboardNotifierProvider.overrideWith(_NullDashboard.new),
          profileNotifierProvider.overrideWith(_NullProfile.new),
        ],
      );
      addTearDown(() {
        container.read(routerProvider).dispose();
        container.dispose();
      });
      await container.read(authNotifierProvider.future);
      // El router se crea al leerlo: su arranque aplica la política.
      container.read(routerProvider);
      await tester.pump();
      return recorded;
    }

    testWidgets('an adult is identified once the router starts',
        (tester) async {
      final recorded = await mount(tester, _adult('adult-1'));
      expect(recorded.identifies, ['identify:adult-1']);
    });

    testWidgets('a pending teen is never identified', (tester) async {
      final recorded = await mount(tester, _teen('teen-1'));
      expect(recorded.identifies, isEmpty);
    });

    testWidgets('a teen with a guardian is never identified', (tester) async {
      final recorded = await mount(
        tester,
        _teen('teen-1', status: SupervisionStatus.active),
      );
      expect(recorded.identifies, isEmpty);
    });

    testWidgets(
        'a later /auth/me that changes the mode goes through the same policy',
        (tester) async {
      final recorded = _RecordingGateway();
      final container = ProviderContainer(
        overrides: [
          analyticsPolicyProvider
              .overrideWithValue(AnalyticsPolicy(gateway: recorded)),
          authNotifierProvider.overrideWith(() => _Auth(null)),
          appBootstrapProvider.overrideWith(_ReadyBootstrap.new),
          dashboardNotifierProvider.overrideWith(_NullDashboard.new),
          profileNotifierProvider.overrideWith(_NullProfile.new),
        ],
      );
      addTearDown(() {
        container.read(routerProvider).dispose();
        container.dispose();
      });
      await container.read(authNotifierProvider.future);
      container.read(routerProvider);
      final auth = container.read(authNotifierProvider.notifier) as _Auth;

      auth.emit(_teen('person-1'));
      await tester.pump();
      expect(recorded.events, isEmpty, reason: 'a teen is not identified');

      // El mismo teléfono: la persona cumple 18 y el servidor lo declara adulto.
      auth.emit(_adult('person-1'));
      await tester.pump();
      expect(recorded.events, ['identify:person-1']);

      // Y si el servidor la vuelve a declarar supervisada, se resetea.
      auth.emit(_teen('person-1'));
      await tester.pump();
      expect(recorded.events, ['identify:person-1', 'reset']);
    });
  });
}

class _ThrowingGateway implements AnalyticsGateway {
  @override
  bool get hasIdentifiedUser => false;

  @override
  Future<void> identify(String userId) async => throw StateError('offline');

  @override
  Future<void> reset() async => throw StateError('offline');
}

class _Auth extends AuthNotifier {
  _Auth(this.user);

  final UserEntity? user;

  @override
  Future<UserEntity?> build() async => user;

  /// Simula el `/auth/me` siguiente.
  void emit(UserEntity? next) => state = AsyncValue.data(next);
}

class _ReadyBootstrap extends AppBootstrapNotifier {
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
