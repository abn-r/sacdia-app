import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../config/route_names.dart';

/// Back action for screens that can also be the first page of the stack
/// (deep link, push notification): goes back when there is a previous page,
/// otherwise to the home dashboard, so the user is never left without a way
/// out.
void backOrHome(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }
  context.go(RouteNames.home);
}
