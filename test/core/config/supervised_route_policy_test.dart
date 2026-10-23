import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/pending_navigation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/supervised_route_policy.dart';
import 'package:sacdia_app/features/auth/domain/entities/principal_info.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

UserEntity _user({
  AccountMode? mode,
  bool postRegisterComplete = true,
  bool legalPending = false,
}) =>
    UserEntity(
      id: 'u1',
      postRegisterComplete: postRegisterComplete,
      legalAcceptancePending: legalPending,
      serverMode: mode,
    );

void main() {
  group('profile_incomplete (no birthday): allowlist', () {
    test('only post-registration and legal are allowed', () {
      expect(
          isAllowedForProfileIncomplete(RouteNames.postRegistration), isTrue);
      expect(isAllowedForProfileIncomplete(RouteNames.legalAcceptance), isTrue);
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.teenPendingHome,
        RouteNames.notificationsInbox,
        '/',
      ]) {
        expect(isAllowedForProfileIncomplete(path), isFalse, reason: path);
      }
    });

    test(
        'everything else goes to post-registration, even if the local flag '
        'says it is done', () {
      for (final needs in [true, false]) {
        expect(
          supervisedRouteRedirect(
            mode: AccountMode.profileIncomplete,
            path: RouteNames.homeDashboard,
            needsPostRegistration: needs,
          ),
          RouteNames.postRegistration,
        );
      }
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.profileIncomplete,
          path: RouteNames.postRegistration,
          needsPostRegistration: false,
        ),
        isNull,
      );
    });

    test('a deferred push is never delivered', () {
      final user = UserEntity(
        id: 'u',
        postRegisterComplete: true,
        serverMode: AccountMode.profileIncomplete,
      );
      expect(
        isPendingNavigationAllowed(
          user: user,
          route: RouteNames.homeDashboard,
          acting: false,
        ),
        isFalse,
      );
    });
  });

  group('restricted (unknown principal): fails closed', () {
    test('only its info screen and legal are allowed', () {
      expect(
          supervisedRouteRedirect(
            mode: AccountMode.restricted,
            path: RouteNames.restrictedAccount,
            needsPostRegistration: false,
          ),
          isNull);
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.postRegistration,
        RouteNames.family,
        RouteNames.teenPendingHome,
      ]) {
        expect(
          supervisedRouteRedirect(
            mode: AccountMode.restricted,
            path: path,
            needsPostRegistration: false,
          ),
          RouteNames.restrictedAccount,
          reason: path,
        );
      }
    });

    test('the info screen does not exist for an adult', () {
      expect(
        supervisedRouteRedirect(
          mode: AccountMode.adult,
          path: RouteNames.restrictedAccount,
          needsPostRegistration: false,
        ),
        RouteNames.homeDashboard,
      );
    });
  });

  group('pending teen: allowlist', () {
    test('only the status screen, post-registration and legal are allowed', () {
      expect(isAllowedForPendingTeen(RouteNames.teenPendingHome), isTrue);
      expect(isAllowedForPendingTeen(RouteNames.postRegistration), isTrue);
      expect(isAllowedForPendingTeen(RouteNames.legalAcceptance), isTrue);
      expect(isAllowedForPendingTeen('/teen/pending/'), isTrue);
    });

    test('club data, member tabs and Mi familia are not', () {
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
        RouteNames.homeMembers,
        RouteNames.homeUnits,
        RouteNames.clubDetailPath('1'),
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.notificationsInbox,
        '/',
      ]) {
        expect(isAllowedForPendingTeen(path), isFalse, reason: path);
      }
    });

    test('a path that merely starts with the same letters is not allowed', () {
      expect(isAllowedForPendingTeen('/teen/pendingx'), isFalse);
      expect(isAllowedForPendingTeen('/post-registrationx'), isFalse);
    });
  });

  group('supervised teen with a guardian: denylist', () {
    test('Mi familia, security, sessions, MFA, deletion and export are blocked',
        () {
      for (final path in [
        RouteNames.family,
        RouteNames.familyAdd,
        RouteNames.familyLink,
        RouteNames.familyDetailPath('ana-1'),
        '/security',
        '/security/password',
        '/sessions',
        '/mfa/setup',
        '/delete-account',
        '/data-export',
      ]) {
        expect(isBlockedForActiveTeen(path), isTrue, reason: path);
      }
    });

    test('the member app stays open', () {
      for (final path in [
        RouteNames.homeDashboard,
        RouteNames.homeClasses,
        RouteNames.homeActivities,
        RouteNames.homeProfile,
        RouteNames.homeUnits,
        RouteNames.homeHonors,
        RouteNames.clubDetailPath('1'),
        RouteNames.notificationsInbox,
        RouteNames.postRegistration,
        RouteNames.legalAcceptance,
      ]) {
        expect(isBlockedForActiveTeen(path), isFalse, reason: path);
      }
    });

    test('lookalike prefixes are not blocked', () {
      expect(isBlockedForActiveTeen('/familyroom'), isFalse);
      expect(isBlockedForActiveTeen('/sessionsx'), isFalse);
    });
  });

  group('supervisedRouteRedirect', () {
    String? go(AccountMode mode, String path, {bool postReg = false}) =>
        supervisedRouteRedirect(
          mode: mode,
          path: path,
          needsPostRegistration: postReg,
        );

    test('adult: nothing, except the teen-only screen', () {
      expect(go(AccountMode.adult, RouteNames.family), isNull);
      expect(go(AccountMode.adult, RouteNames.homeClasses), isNull);
      expect(
        go(AccountMode.adult, RouteNames.teenPendingHome),
        RouteNames.homeDashboard,
      );
    });

    test('pending teen is pulled back to the status screen', () {
      expect(
        go(AccountMode.teenPending, RouteNames.homeDashboard),
        RouteNames.teenPendingHome,
      );
      expect(go(AccountMode.teenPending, RouteNames.teenPendingHome), isNull);
    });

    test('pending teen without post-registration goes to the steps instead',
        () {
      expect(
        go(AccountMode.teenPending, RouteNames.homeDashboard, postReg: true),
        RouteNames.postRegistration,
      );
      expect(
        go(AccountMode.teenPending, RouteNames.postRegistration, postReg: true),
        isNull,
      );
    });

    test('supervised teen: member app free, family and status screen not', () {
      expect(go(AccountMode.teenSupervised, RouteNames.homeClasses), isNull);
      expect(
        go(AccountMode.teenSupervised, RouteNames.family),
        RouteNames.homeDashboard,
      );
      expect(
        go(AccountMode.teenSupervised, RouteNames.teenPendingHome),
        RouteNames.homeDashboard,
      );
    });
  });

  group('isPendingNavigationAllowed (deferred pushes)', () {
    bool allowed(
      UserEntity user,
      String route, {
      bool acting = false,
    }) =>
        isPendingNavigationAllowed(user: user, route: route, acting: acting);

    test('an adult receives a normal destination', () {
      expect(allowed(_user(), RouteNames.notificationsInbox), isTrue);
    });

    test('a pending teen does not get member destinations', () {
      final teen = _user(mode: AccountMode.teenPending);
      expect(allowed(teen, RouteNames.notificationsInbox), isFalse);
      expect(allowed(teen, RouteNames.clubDetailPath('1')), isFalse);
    });

    test('a supervised teen gets member destinations but not Mi familia', () {
      final teen = _user(mode: AccountMode.teenSupervised);
      expect(allowed(teen, RouteNames.notificationsInbox), isTrue);
      expect(allowed(teen, RouteNames.family), isFalse);
    });

    test('nothing is delivered over the legal gate or an unfinished signup',
        () {
      expect(
        allowed(_user(legalPending: true), RouteNames.notificationsInbox),
        isFalse,
      );
      expect(
        allowed(
          _user(postRegisterComplete: false),
          RouteNames.notificationsInbox,
        ),
        isFalse,
      );
    });

    test('while acting for a minor, Mi familia is not delivered', () {
      expect(allowed(_user(), RouteNames.family, acting: true), isFalse);
      expect(
        allowed(_user(), RouteNames.notificationsInbox, acting: true),
        isTrue,
      );
    });
  });
}
