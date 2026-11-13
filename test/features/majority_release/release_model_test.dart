import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/release_route_policy.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/supervised_route_policy.dart';
import 'package:sacdia_app/features/auth/data/models/user_model.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

Map<String, dynamic> _payload([Map<String, dynamic>? extra]) => {
      'user_id': 'user-1',
      'email': 'user@example.com',
      ...?extra,
    };

Map<String, dynamic> _release({
  String status = 'pending',
  bool needsAcceptance = true,
  bool needsEmail = false,
  String? loginMethod,
  String? deadline = '2026-12-10T09:30:00.000Z',
  String? frozenAt,
  String? purgeAfter,
}) =>
    {
      'status': status,
      'released_at': '2026-11-10T09:30:00.000Z',
      'deadline_at': deadline,
      'frozen_at': frozenAt,
      'purge_after': purgeAfter,
      'needs_acceptance': needsAcceptance,
      'needs_email': needsEmail,
      'login_method': loginMethod,
    };

UserEntity _released({
  bool frozen = false,
  AccountMode? serverMode = AccountMode.released,
  bool legalPending = false,
}) =>
    UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      serverMode: serverMode,
      legalAcceptancePending: legalPending,
      principal: PrincipalInfo(
        kind: PrincipalKind.releasedUser,
        release: ReleaseInfo(
          status: frozen ? ReleaseStatus.frozen : ReleaseStatus.pending,
        ),
      ),
      analyticsAnonymous: false,
    );

void main() {
  group('PrincipalKind / AccountMode (FP4-67, FP4-69)', () {
    test('released_user is understood; anything else new stays unknown', () {
      expect(PrincipalKind.parse('released_user'), PrincipalKind.releasedUser);
      expect(PrincipalKind.parse('released_user_v2'), PrincipalKind.unknown);
      expect(AccountMode.parse('released'), AccountMode.released);
      // Un modo que ESTA build no conoce sigue fallando cerrado.
      expect(AccountMode.parse('released_v2'), AccountMode.restricted);
    });

    test('an unknown principal kind is still restricted (old-build behaviour)',
        () {
      const user = UserEntity(
        id: 'u',
        principal: PrincipalInfo(kind: PrincipalKind.unknown),
        serverMode: AccountMode.released,
      );
      expect(user.mode, AccountMode.restricted);
    });

    test('the principal decides the mode, not a declared adult mode', () {
      final user = _released(serverMode: AccountMode.adult);
      expect(user.mode, AccountMode.released);
      expect(user.isReleased, isTrue);
      expect(user.isLimitedAccount, isTrue);
    });

    test('a released user is never identified in analytics', () {
      expect(_released().canIdentifyInAnalytics, isFalse);
    });

    test('the generic legal gate never claims a released user', () {
      expect(userNeedsLegalAcceptance(_released(legalPending: true)), isFalse);
      expect(
        userNeedsLegalAcceptance(const UserEntity(
          id: 'a',
          legalAcceptancePending: true,
          principal: PrincipalInfo(kind: PrincipalKind.user),
        )),
        isTrue,
      );
    });

    test('release getters', () {
      expect(_released().isReleaseFrozen, isFalse);
      expect(_released(frozen: true).isReleaseFrozen, isTrue);
      expect(
        const UserEntity(
                id: 'a', principal: PrincipalInfo(kind: PrincipalKind.user))
            .release,
        isNull,
      );
    });
  });

  group('/auth/me parsing', () {
    test('parses principal.release and the feature flag', () {
      final user = UserModel.fromCustomApi(_payload({
        'mode': 'released',
        'family_features': {'majority_release': true},
        'principal': {
          'kind': 'released_user',
          'scopes': ['release:read', 'legal:accept'],
          'release': _release(needsEmail: true, loginMethod: 'handle'),
        },
      }));
      expect(user.mode, AccountMode.released);
      expect(user.majorityReleaseEnabled, isTrue);
      final release = user.release!;
      expect(release.status, ReleaseStatus.pending);
      expect(release.needsAcceptance, isTrue);
      expect(release.needsEmail, isTrue);
      expect(release.loginMethod, ReleaseLoginMethod.handle);
      expect(release.deadlineAt, DateTime.parse('2026-12-10T09:30:00.000Z'));
      expect(release.isFrozen, isFalse);
    });

    test('a frozen release has no purge date to show (R6)', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {
          'kind': 'released_user',
          'release': _release(
            status: 'frozen',
            deadline: null,
            frozenAt: '2026-12-11T09:30:00.000Z',
          ),
        },
      }));
      expect(user.isReleaseFrozen, isTrue);
      expect(user.release!.purgeAfter, isNull);
      expect(user.release!.daysLeftAt(DateTime.utc(2026, 12, 12)), isNull);
    });

    test('a missing or unknown release block is null: pending by default', () {
      for (final bad in <Object?>[
        null,
        'x',
        {'status': 'weird'}
      ]) {
        final user = UserModel.fromCustomApi(_payload({
          'principal': {'kind': 'released_user', 'release': bad},
        }));
        expect(user.mode, AccountMode.released);
        expect(user.release, isNull);
        expect(user.isReleaseFrozen, isFalse);
      }
    });

    test('only an explicit needs_acceptance=false counts as accepted', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {
          'kind': 'released_user',
          'release': _release(needsAcceptance: false),
        },
      }));
      expect(user.release!.needsAcceptance, isFalse);
      final missing = UserModel.fromCustomApi(_payload({
        'principal': {
          'kind': 'released_user',
          'release': {'status': 'pending'},
        },
      }));
      expect(missing.release!.needsAcceptance, isTrue);
    });

    test('the release block is ignored for any other principal', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {'kind': 'user', 'release': _release()},
      }));
      expect(user.principal!.release, isNull);
      expect(user.mode, AccountMode.adult);
    });

    test('the feature flag defaults to off', () {
      expect(
        UserModel.fromCustomApi(_payload({'family_features': {}}))
            .majorityReleaseEnabled,
        isFalse,
      );
      expect(
          UserModel.fromCustomApi(_payload()).majorityReleaseEnabled, isFalse);
    });

    test('teen supervision carries the majority notice window', () {
      final user = UserModel.fromCustomApi(_payload({
        'principal': {
          'kind': 'supervised_user',
          'supervision': {
            'status': 'active',
            'majority_date': '2026-12-01',
            'release_notice_sent': true,
          },
        },
      }));
      final s = user.principal!.supervision!;
      expect(s.hasMajorityNotice, isTrue);
      expect(s.majorityDate, DateTime(2026, 12, 1));
      expect(s.majorityDaysLeftAt(DateTime(2026, 11, 21, 15)), 10);
      expect(s.majorityDaysLeftAt(DateTime(2026, 12, 5)), 0);

      final none = UserModel.fromCustomApi(_payload({
        'principal': {
          'kind': 'supervised_user',
          'supervision': {'status': 'active'},
        },
      }));
      expect(none.principal!.supervision!.hasMajorityNotice, isFalse);
    });
  });

  group('ReleaseInfo.daysLeftAt', () {
    test('rounds up and never goes negative', () {
      final info = ReleaseInfo(
        status: ReleaseStatus.pending,
        deadlineAt: DateTime.utc(2026, 12, 10, 9),
      );
      expect(info.daysLeftAt(DateTime.utc(2026, 12, 8, 10)), 2);
      expect(info.daysLeftAt(DateTime.utc(2026, 12, 10, 8)), 1);
      expect(info.daysLeftAt(DateTime.utc(2026, 12, 11)), 0);
      expect(
          const ReleaseInfo(status: ReleaseStatus.pending)
              .daysLeftAt(DateTime.utc(2026, 12, 8)),
          isNull);
    });
  });

  group('release route policy', () {
    test('pending whitelist: /release and /access-denied only', () {
      expect(
        releaseRouteRedirect(path: RouteNames.release, frozen: false),
        isNull,
      );
      expect(
        releaseRouteRedirect(path: RouteNames.accessDenied, frozen: false),
        isNull,
      );
      for (final path in [
        RouteNames.releaseFrozen,
        RouteNames.homeDashboard,
        RouteNames.family,
        RouteNames.login,
        RouteNames.splash,
        RouteNames.legalAcceptance,
        RouteNames.adultClaim,
        RouteNames.postRegistration,
      ]) {
        expect(
          releaseRouteRedirect(path: path, frozen: false),
          RouteNames.release,
          reason: path,
        );
      }
    });

    test('frozen whitelist: /release/frozen, /release (thaw), /access-denied',
        () {
      for (final path in [
        RouteNames.releaseFrozen,
        RouteNames.release,
        RouteNames.accessDenied,
      ]) {
        expect(releaseRouteRedirect(path: path, frozen: true), isNull,
            reason: path);
      }
      expect(
        releaseRouteRedirect(path: RouteNames.homeDashboard, frozen: true),
        RouteNames.releaseFrozen,
      );
    });

    test('trailing slashes are normalized', () {
      expect(releaseRouteRedirect(path: '/release/', frozen: false), isNull);
    });

    test('accountHomeFor(released) follows the status', () {
      expect(
        accountHomeFor(AccountMode.released, needsPostRegistration: true),
        RouteNames.release,
      );
      expect(
        accountHomeFor(
          AccountMode.released,
          needsPostRegistration: false,
          releaseFrozen: true,
        ),
        RouteNames.releaseFrozen,
      );
    });

    test('supervisedRouteRedirect: released delegates, others leave /release',
        () {
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.released,
          path: RouteNames.homeDashboard,
          needsPostRegistration: false,
        ),
        RouteNames.release,
      );
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.adult,
          path: RouteNames.release,
          needsPostRegistration: false,
        ),
        RouteNames.homeDashboard,
      );
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.teenSupervised,
          path: RouteNames.releaseFrozen,
          needsPostRegistration: false,
        ),
        RouteNames.homeDashboard,
      );
    });
  });

  group('AuthNotifier.authorizationChanged (Fase 4)', () {
    test('a release -> adult transition republishes even if permissions match',
        () {
      final released = _released();
      const adult = UserEntity(
        id: 'u1',
        email: 'u1@example.com',
        principal: PrincipalInfo(kind: PrincipalKind.user),
      );
      expect(AuthNotifier.authorizationChanged(released, adult), isTrue);
      // Aceptar documentos cambia `needs_acceptance` dentro del principal.
      final accepted = UserEntity(
        id: 'u1',
        email: 'u1@example.com',
        serverMode: AccountMode.released,
        principal: const PrincipalInfo(
          kind: PrincipalKind.releasedUser,
          release: ReleaseInfo(
            status: ReleaseStatus.pending,
            needsAcceptance: false,
          ),
        ),
      );
      expect(AuthNotifier.authorizationChanged(released, accepted), isTrue);
      expect(AuthNotifier.authorizationChanged(released, _released()), isFalse);
    });
  });
}
