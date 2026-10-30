import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

/// Quick-access modules (Members, Club, Finances…) are siblings of the
/// dashboard inside its shell branch, not children of it. A `go` to one of
/// them replaces the branch stack: there is no way back and the Inicio tab
/// reopens the module. Opening one from outside the dashboard (the inbox, a
/// push tap) goes to the dashboard first and pushes the module on top, the
/// same stack the quick-access grid builds.
const Set<String> dashboardDrillInRoutes = {
  RouteNames.homeMembers,
  RouteNames.homeMemberRequests,
  RouteNames.homeClub,
  RouteNames.homeEvidences,
  RouteNames.homeFinances,
  RouteNames.homeUnits,
  RouteNames.homeInsurance,
  RouteNames.homeInventory,
  RouteNames.homeResources,
  RouteNames.homeHonors,
  RouteNames.homeCertifications,
  RouteNames.homeCamporees,
  RouteNames.homeAchievements,
};

bool isDashboardDrillIn(String route) =>
    dashboardDrillInRoutes.contains(route) ||
    dashboardDrillInRoutes.contains(Uri.parse(route).path);

/// Opens [route] (a dashboard drill-in) with the dashboard underneath it.
Future<void> openDashboardDrillIn(GoRouter router, String route) async {
  router.go(RouteNames.homeDashboard);
  // Let the router apply the new location before stacking on top of it.
  await WidgetsBinding.instance.endOfFrame;
  router.push(route);
}
