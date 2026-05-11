import 'package:equatable/equatable.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

/// Identifies which provider (or fallback) should source the badge count for
/// a given nav slot. Used by [NavBadge] to decide which stream to watch.
enum NavBadgeSource {
  /// Activities unread count — universal fallback for all personas.
  activities,

  /// Unit-scope badge (Consejero: Mi Unidad slot).
  unit,

  /// Members-scope badge (Director: Miembros slot).
  members,

  /// Finances-scope badge (Tesorero: Finanzas slot).
  finances,

  /// Coordinator hub badge (Coordinador: Hub slot).
  hub,

  /// No badge rendered on this slot.
  none,
}

/// A single bottom-navigation slot configuration, persona-aware and
/// fully declarative.
///
/// [branchIndex] must match the position of the corresponding
/// [StatefulShellBranch] in the [StatefulShellRoute.indexedStack] branches
/// list. This value MUST remain stable across releases to preserve deep-link
/// and push-notification routing.
///
/// [icon] must be a [HugeIconData] — the HugeIcons typedef
/// (`List<List<dynamic>>`). Raw [IconData] is not supported.
///
/// [labelKey] is resolved at render time via `tr(labelKey)` using
/// EasyLocalization.
///
/// [badgeSource] controls whether a notification badge appears on this slot.
/// When [NavBadgeSource.none], no badge widget is rendered.
class NavSlot extends Equatable {
  final HugeIconData icon;

  /// EasyLocalization translation key, e.g. `'nav.dashboard'`.
  final String labelKey;

  /// Stable shell branch index — must match the router's branches list.
  final int branchIndex;

  /// GoRouter route path, e.g. [RouteNames.homeDashboard].
  final String route;

  /// Badge data source. Defaults to [NavBadgeSource.none].
  final NavBadgeSource badgeSource;

  const NavSlot({
    required this.icon,
    required this.labelKey,
    required this.branchIndex,
    required this.route,
    this.badgeSource = NavBadgeSource.none,
  });

  @override
  List<Object?> get props => [
        icon,
        labelKey,
        branchIndex,
        route,
        badgeSource,
      ];
}
