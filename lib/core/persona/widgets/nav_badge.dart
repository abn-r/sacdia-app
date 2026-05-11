import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/persona/nav_slot.dart';
import 'package:sacdia_app/features/notifications/presentation/providers/unread_notifications_count_provider.dart';

/// Wraps [child] with a notification badge driven by [source].
///
/// When [source] is [NavBadgeSource.none], the child is returned unwrapped.
/// When [source] is any active value, the widget watches
/// [unreadNotificationsCountProvider] and overlays a red circular badge in the
/// top-right corner when the count is greater than zero.
///
/// Design constraints (NFR-3, NFR-4):
/// - Badge uses `Theme.of(context).colorScheme.error` (Material 3 semantic token).
/// - Badge counter is capped at 99+.
/// - Touch target maintained by parent [NavigationDestination] / [NavigationRailDestination].
///
/// Usage:
/// ```dart
/// NavBadge(
///   source: slot.badgeSource,
///   child: HugeIcon(icon: slot.icon),
/// )
/// ```
class NavBadge extends ConsumerWidget {
  const NavBadge({
    super.key,
    required this.source,
    required this.child,
  });

  final NavBadgeSource source;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (source == NavBadgeSource.none) {
      return child;
    }

    final count = ref.watch(unreadNotificationsCountProvider);

    if (count <= 0) {
      return child;
    }

    final badgeLabel = count > 99 ? '99+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -6,
          child: Semantics(
            label: 'nav.unread_notifications_a11y'
                .tr(namedArgs: {'count': badgeLabel}),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onError,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
