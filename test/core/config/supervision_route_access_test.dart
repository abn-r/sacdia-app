import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/config/coordinator_route_access.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/config/supervision_route_access.dart';
import 'package:sacdia_app/features/auth/domain/entities/authorization_snapshot.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';

UserEntity _user(List<String> capabilities) => UserEntity(
      id: 'u1',
      email: 'u1@example.com',
      authorization: AuthorizationSnapshot(capabilities: capabilities),
    );

void main() {
  group('isSupervisionAllowedPath', () {
    test('allows home, profile, inbox, denied screen, hub and Mi familia', () {
      for (final allowed in [
        RouteNames.homeDashboard,
        RouteNames.homeProfile,
        RouteNames.homeMedicalInfo,
        RouteNames.notificationsInbox,
        RouteNames.accessDenied,
        RouteNames.supervision,
        '${RouteNames.supervision}/',
        RouteNames.supervisionEnrollments,
        RouteNames.supervisionFolders,
        RouteNames.supervisionFolderDetail('f1'),
        RouteNames.supervisionRequests,
        RouteNames.supervisionOperations,
        RouteNames.supervisionClubs,
        RouteNames.supervisionClubDetail('c1'),
        RouteNames.supervisionReports,
        RouteNames.supervisionAnnualProgress,
        RouteNames.supervisionUnionCamporees,
        RouteNames.supervisionUnionCamporeeApprovals('9'),
        RouteNames.supervisionUnionCamporeeOrders('9'),
        RouteNames.family,
        RouteNames.familyDetailPath('d1'),
      ]) {
        expect(isSupervisionAllowedPath(allowed), isTrue, reason: allowed);
      }
    });

    test('every route name declared for supervision is allowed', () {
      for (final route in [
        RouteNames.supervision,
        RouteNames.supervisionEnrollments,
        RouteNames.supervisionFolders,
        RouteNames.supervisionRequests,
        RouteNames.supervisionOperations,
        RouteNames.supervisionClubs,
        RouteNames.supervisionReports,
        RouteNames.supervisionAnnualProgress,
        RouteNames.supervisionUnionCamporees,
      ]) {
        expect(isSupervisionAllowedPath(route), isTrue, reason: route);
      }
    });

    test('blocks club-only, coordination and panel-only routes', () {
      for (final blocked in [
        RouteNames.homeHonors,
        RouteNames.homeClasses,
        RouteNames.homeClub,
        RouteNames.homeMembers,
        RouteNames.homeActivities,
        RouteNames.coordinator,
        RouteNames.coordinatorClubs,
        RouteNames.investitureAuthorize,
        RouteNames.ownInvestiture,
        RouteNames.clubDetailPath('1'),
        RouteNames.panelOnlyAccount,
        '/supervisionx',
        '/familyx',
      ]) {
        expect(isSupervisionAllowedPath(blocked), isFalse, reason: blocked);
      }
    });
  });

  group('unconfiguredSupervisionRedirect', () {
    String? redirect(String? level, String path) =>
        unconfiguredSupervisionRedirect(territoryLevel: level, path: path);

    test('the sentinel level matches the server value', () {
      expect(kUnconfiguredTerritoryLevel, 'unconfigured');
    });

    test('sends every route below the hub back to the hub when unconfigured',
        () {
      for (final path in [
        RouteNames.supervisionEnrollments,
        RouteNames.supervisionFolders,
        RouteNames.supervisionFolderDetail('abc'),
        RouteNames.supervisionOperations,
        RouteNames.supervisionUnionCamporees,
        RouteNames.supervisionUnionCamporeeOrders('7'),
      ]) {
        expect(
          redirect(kUnconfiguredTerritoryLevel, path),
          RouteNames.supervision,
          reason: path,
        );
      }
    });

    test('lets the hub and unrelated paths stay when unconfigured', () {
      for (final path in [
        RouteNames.supervision,
        RouteNames.homeDashboard,
        '/supervisionx',
        '/supervisionx/enrollments',
        RouteNames.family,
      ]) {
        expect(redirect(kUnconfiguredTerritoryLevel, path), isNull,
            reason: path);
      }
    });

    test('never redirects with a configured or missing level', () {
      for (final level in ['union', 'division', null, '', 'Unconfigured']) {
        expect(
          redirect(level, RouteNames.supervisionEnrollments),
          isNull,
          reason: '$level',
        );
      }
    });
  });

  group('clubLessRouteRedirect for a supervisor', () {
    test('the supervision allow-list wins; the rest goes to the home', () {
      final user = _user(const ['supervision.app_view']);
      expect(clubLessRouteRedirect(user, RouteNames.supervision), isNull);
      expect(
        clubLessRouteRedirect(user, RouteNames.supervisionClubs),
        isNull,
      );
      expect(clubLessRouteRedirect(user, RouteNames.family), isNull);
      expect(
        clubLessRouteRedirect(user, RouteNames.homeHonors),
        RouteNames.homeDashboard,
      );
      expect(
        clubLessRouteRedirect(user, RouteNames.coordinator),
        RouteNames.homeDashboard,
      );
    });

    test('with hub_view the coordinator routes are merged in', () {
      final user =
          _user(const ['supervision.app_view', 'coordination.hub_view']);
      expect(clubLessRouteRedirect(user, RouteNames.supervision), isNull);
      expect(clubLessRouteRedirect(user, RouteNames.coordinator), isNull);
      expect(clubLessRouteRedirect(user, RouteNames.coordinatorSla), isNull);
      expect(
        clubLessRouteRedirect(user, RouteNames.homeHonors),
        RouteNames.homeDashboard,
      );
    });

    test('with pastor and supervision the supervisor persona wins', () {
      final user = _user(const [
        'supervision.app_view',
        'admin_panel.pastor_only',
      ]);
      expect(clubLessRouteRedirect(user, RouteNames.supervision), isNull);
      expect(
        clubLessRouteRedirect(user, RouteNames.investitureAuthorize),
        RouteNames.homeDashboard,
      );
    });

    test('with the authorizer capability the investiture routes survive', () {
      final user = _user(const [
        'supervision.app_view',
        'investiture.authorize_requests',
      ]);
      expect(
        clubLessRouteRedirect(user, RouteNames.investitureAuthorize),
        isNull,
      );
    });
  });
}
