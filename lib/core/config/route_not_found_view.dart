import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../widgets/sac_empty_state.dart';
import 'route_names.dart';

/// Shown when go_router cannot match a location: a link to a screen that no
/// longer exists, or a malformed `sacdia://` link from a push, email or QR.
///
/// The location is never shown: a link may carry a token.
class RouteNotFoundView extends StatelessWidget {
  const RouteNotFoundView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SacEmptyState(
              icon: HugeIcons.strokeRoundedLink01,
              title: 'router.not_found.title'.tr(),
              body: 'router.not_found.body'.tr(),
              actionLabel: 'router.not_found.action'.tr(),
              actionIcon: HugeIcons.strokeRoundedHome01,
              // Splash sends each session mode (account, teen, linked device,
              // signed out) to its own start screen.
              onAction: () => context.go(RouteNames.splash),
            ),
          ),
        ),
      ),
    );
  }
}
