import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../config/route_names.dart';

/// Back action for screens that can also be the first page of the stack
/// (deep link, push notification): goes back when there is a previous page,
/// otherwise to the home dashboard, so the user is never left without a way
/// out.
void backOrHome(BuildContext context) {
  // A second tap while the page is already leaving: the pop is under way.
  // Without this check canPop() is false by then and the tap would also jump
  // to the dashboard.
  if (!context.mounted) return;
  final route = ModalRoute.of(context);
  if (route != null && !route.isActive) return;

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  // `/home` alone is not a route: the dashboard lives at `/home/dashboard`.
  context.go(RouteNames.homeDashboard);
}
