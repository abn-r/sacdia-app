import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/panel_only_route_policy.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/supervised_route_policy.dart';
import 'package:sacdia_app/features/auth/domain/entities/acting_for_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/onboarding_mode.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

const _guardianFamily = FamilySummary(isGuardian: true, dependentsCount: 2);

UserEntity _user({
  OnboardingMode mode = OnboardingMode.panelOnly,
  FamilySummary? family,
  ActingForInfo? actingFor,
  PrincipalInfo? principal,
  AccountMode? serverMode,
  bool postRegisterComplete = false,
}) =>
    UserEntity(
      id: 'u1',
      onboardingMode: mode,
      family: family,
      actingFor: actingFor,
      principal: principal,
      serverMode: serverMode,
      postRegisterComplete: postRegisterComplete,
    );

const _familyPaths = [
  RouteNames.family,
  RouteNames.familyAdd,
  RouteNames.familyLink,
  RouteNames.familyReleased,
  '/family/ana-1',
  '/family/ana-1/summary',
  '/family/ana-1/teen-login',
  '/family/ana-1/pair-device',
];

void main() {
  group('panel-only account without dependents', () {
    final user = _user();

    test('sends every club path to the panel-only screen', () {
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.homeClasses,
        RouteNames.postRegistration,
        RouteNames.notificationsInbox,
        RouteNames.coordinator,
        '/',
        ..._familyPaths,
      ]) {
        expect(
          panelOnlyRouteRedirect(user, path),
          RouteNames.panelOnlyAccount,
          reason: path,
        );
      }
    });

    test('lets the screen and /access-denied through', () {
      expect(panelOnlyRouteRedirect(user, RouteNames.panelOnlyAccount), isNull);
      expect(panelOnlyRouteRedirect(user, '/account/panel-only/'), isNull);
      expect(panelOnlyRouteRedirect(user, RouteNames.accessDenied), isNull);
    });

    test('a family snapshot that is not a guardian grants no family access',
        () {
      final notGuardian = _user(
        family: const FamilySummary(isGuardian: false, dependentsCount: 0),
      );
      expect(
        panelOnlyRouteRedirect(notGuardian, RouteNames.family),
        RouteNames.panelOnlyAccount,
      );
    });

    test('a path that only starts with /family is not a family path', () {
      final guardian = _user(family: _guardianFamily);
      expect(
        panelOnlyRouteRedirect(guardian, '/family-x'),
        RouteNames.panelOnlyAccount,
      );
    });

    test('its home is the panel-only screen', () {
      expect(
        accountHomeFor(
          AccountMode.adult,
          needsPostRegistration: false,
          panelOnly: isPanelOnlyAccount(user),
        ),
        RouteNames.panelOnlyAccount,
      );
      expect(
        accountHomeFor(AccountMode.adult, needsPostRegistration: false),
        RouteNames.homeDashboard,
      );
    });
  });

  group('panel-only guardian', () {
    final guardian = _user(family: _guardianFamily);

    test('keeps every /family path', () {
      for (final path in _familyPaths) {
        expect(panelOnlyRouteRedirect(guardian, path), isNull, reason: path);
      }
    });

    test('a guardian by dependents_count alone also qualifies', () {
      final byCount = _user(
        family: const FamilySummary(isGuardian: false, dependentsCount: 1),
      );
      expect(panelOnlyRouteRedirect(byCount, '/family/ana-1'), isNull);
    });

    test('still loses everything outside /family', () {
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.postRegistration,
      ]) {
        expect(
          panelOnlyRouteRedirect(guardian, path),
          RouteNames.panelOnlyAccount,
          reason: path,
        );
      }
    });
  });

  group('acting for a dependent', () {
    const acting = ActingForInfo(
      actorUserId: 'guardian-1',
      dependentUserId: 'ana-1',
    );

    test('the gate does not apply to the dependent session', () {
      final dependent = _user(
        mode: OnboardingMode.club,
        actingFor: acting,
        postRegisterComplete: true,
      );
      expect(isPanelOnlyAccount(dependent), isFalse);
      expect(
          panelOnlyRouteRedirect(dependent, RouteNames.homeDashboard), isNull);
      expect(panelOnlyRouteRedirect(dependent, RouteNames.homeClasses), isNull);
    });

    test('even a panel_only payload while acting is not gated', () {
      final odd = _user(actingFor: acting, family: _guardianFamily);
      expect(isPanelOnlyAccount(odd), isFalse);
      expect(panelOnlyRouteRedirect(odd, RouteNames.homeDashboard), isNull);
    });

    test('the dependent cannot open the panel-only screen', () {
      final dependent = _user(
        mode: OnboardingMode.club,
        actingFor: acting,
        postRegisterComplete: true,
      );
      expect(
        panelOnlyRouteRedirect(dependent, RouteNames.panelOnlyAccount),
        RouteNames.homeDashboard,
      );
    });
  });

  group('accounts that are not panel-only', () {
    test('club and club_exempt accounts are untouched', () {
      for (final mode in [OnboardingMode.club, OnboardingMode.clubExempt]) {
        final user = _user(mode: mode, postRegisterComplete: true);
        expect(panelOnlyRouteRedirect(user, RouteNames.homeDashboard), isNull);
        expect(panelOnlyRouteRedirect(user, RouteNames.family), isNull);
      }
    });

    test('opening the panel-only screen sends them home', () {
      final complete = _user(
        mode: OnboardingMode.club,
        postRegisterComplete: true,
      );
      expect(
        panelOnlyRouteRedirect(complete, RouteNames.panelOnlyAccount),
        RouteNames.homeDashboard,
      );
      final pending = _user(mode: OnboardingMode.club);
      expect(
        panelOnlyRouteRedirect(pending, RouteNames.panelOnlyAccount),
        RouteNames.postRegistration,
      );
      final exempt = _user(
        mode: OnboardingMode.clubExempt,
        postRegisterComplete: true,
      );
      expect(
        panelOnlyRouteRedirect(exempt, RouteNames.panelOnlyAccount),
        RouteNames.homeDashboard,
      );
    });
  });

  group('other account modes keep their own gates', () {
    final others = <String, UserEntity>{
      'supervised teen': _user(
        principal: const PrincipalInfo(
          kind: PrincipalKind.supervisedUser,
          supervision: SupervisionInfo(status: SupervisionStatus.active),
        ),
        postRegisterComplete: true,
      ),
      'pending teen': _user(
        principal: const PrincipalInfo(
          kind: PrincipalKind.supervisedUser,
          supervision:
              SupervisionInfo(status: SupervisionStatus.pendingGuardian),
        ),
        postRegisterComplete: true,
      ),
      'linked device': _user(
        principal: const PrincipalInfo(kind: PrincipalKind.linkedDevice),
        postRegisterComplete: true,
      ),
      'restricted': _user(
        principal: const PrincipalInfo(kind: PrincipalKind.unknown),
      ),
      'profile incomplete': _user(
        principal: const PrincipalInfo(kind: PrincipalKind.ageUnknownUser),
      ),
      'released': _user(
        principal: const PrincipalInfo(kind: PrincipalKind.releasedUser),
      ),
    };

    for (final entry in others.entries) {
      test('${entry.key} is not a panel-only account', () {
        expect(isPanelOnlyAccount(entry.value), isFalse);
        expect(
          panelOnlyRouteRedirect(entry.value, RouteNames.homeDashboard),
          isNull,
        );
      });

      test('${entry.key} cannot open the panel-only screen', () {
        expect(
          panelOnlyRouteRedirect(entry.value, RouteNames.panelOnlyAccount),
          isNotNull,
        );
      });
    }
  });

  group('pending navigation (push / deep link)', () {
    test('a non-guardian only receives the screen and /access-denied', () {
      final user = _user();
      bool allowed(String route) => isPendingNavigationAllowed(
            user: user,
            route: route,
            acting: false,
          );
      expect(allowed(RouteNames.panelOnlyAccount), isTrue);
      expect(allowed(RouteNames.accessDenied), isTrue);
      expect(allowed(RouteNames.homeDashboard), isFalse);
      expect(allowed('/family/ana-1'), isFalse);
      expect(allowed(RouteNames.notificationsInbox), isFalse);
    });

    test('a guardian also receives family destinations', () {
      final user = _user(family: _guardianFamily);
      bool allowed(String route) => isPendingNavigationAllowed(
            user: user,
            route: route,
            acting: false,
          );
      expect(allowed('/family/ana-1'), isTrue);
      expect(allowed(RouteNames.family), isTrue);
      expect(allowed(RouteNames.homeDashboard), isFalse);
    });

    test('a club account is not delivered the panel-only screen', () {
      final user = _user(
        mode: OnboardingMode.club,
        postRegisterComplete: true,
      );
      expect(
        isPendingNavigationAllowed(
          user: user,
          route: RouteNames.panelOnlyAccount,
          acting: false,
        ),
        isFalse,
      );
      expect(
        isPendingNavigationAllowed(
          user: user,
          route: RouteNames.homeDashboard,
          acting: false,
        ),
        isTrue,
      );
    });
  });
}
