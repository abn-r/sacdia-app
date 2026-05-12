import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/nav/destinations.dart';
import 'package:sacdia_app/core/persona/persona.dart';
import 'package:sacdia_app/core/persona/persona_nav_config.dart';
import 'package:sacdia_app/core/persona/persona_providers.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/domain/entities/user_entity.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

// ─── Sheet logic ──────────────────────────────────────────────────────────────

/// Value object that pairs a [NavDestination] with its resolved route.
class MoreSheetResolvedItem {
  final NavDestination dest;
  final String resolvedRoute;

  const MoreSheetResolvedItem(
      {required this.dest, required this.resolvedRoute});
}

/// Pure filtering function: returns items from [appDestinations] that
/// pass the persona-slot dedup and RBAC checks.
///
/// Filtering rules (applied in order):
/// 1. Remove items whose static route is in [navRoutes].
/// 2. Remove items the user has no RBAC access to (no permission AND no role).
/// 3. Remove items with a dynamic [routeResolver] that resolves to null.
///
/// [ref] is optional — when provided, dynamic route resolvers are evaluated.
/// When null (e.g. in unit tests without a widget tree), dynamic-route items
/// are skipped.
@visibleForTesting
List<MoreSheetResolvedItem> filterSheetDestinations({
  required Set<String> navRoutes,
  required UserEntity? user,
  WidgetRef? ref,
}) {
  final result = <MoreSheetResolvedItem>[];
  for (final dest in appDestinations) {
    // 1. Skip if static route is already in persona nav slots.
    if (dest.routeResolver == null && navRoutes.contains(dest.route)) continue;

    // 2. RBAC gate — same predicate used by the former QuickAccessGrid (now removed).
    if (dest.requiredPermissions.isEmpty && dest.requiredRoles.isEmpty) {
      // Ungated — visible to all authenticated users.
    } else {
      final hasPermission = dest.requiredPermissions.isNotEmpty &&
          hasAnyPermission(user, dest.requiredPermissions);
      final hasRole =
          dest.requiredRoles.isNotEmpty && hasAnyRole(user, dest.requiredRoles);
      if (!hasPermission && !hasRole) continue;
    }

    // 3. Dynamic route resolution — hide when context data is unavailable.
    String resolvedRoute;
    if (dest.routeResolver != null) {
      if (ref == null) continue; // No ref available to resolve dynamic route.
      final resolved = dest.routeResolver!(ref);
      if (resolved == null) continue;
      if (navRoutes.contains(resolved)) continue; // Dedup vs nav slots.
      resolvedRoute = resolved;
    } else {
      resolvedRoute = dest.route;
    }

    result.add(MoreSheetResolvedItem(dest: dest, resolvedRoute: resolvedRoute));
  }
  return result;
}

/// Provider-aware wrapper: reads auth from [ref] and delegates to
/// [filterSheetDestinations].
@visibleForTesting
List<MoreSheetResolvedItem> buildSheetItems({
  required Persona persona,
  required WidgetRef ref,
}) {
  final navRoutes = personaNavConfig[persona]!.map((s) => s.route).toSet();
  final user = ref.read(authNotifierProvider).valueOrNull;
  return filterSheetDestinations(navRoutes: navRoutes, user: user, ref: ref);
}

// ─── Public API ───────────────────────────────────────────────────────────────

/// Opens the «Más» bottom sheet for the current persona.
///
/// Call from any entry point (dashboard action bar, profile tile, etc.):
/// ```dart
/// showMoreSheet(context: context, ref: ref);
/// ```
void showMoreSheet({required BuildContext context, required WidgetRef ref}) {
  // Capture the parent container before the sheet opens so that the sheet
  // inherits all provider overrides from the calling scope.
  final container = ProviderScope.containerOf(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: const _MoreSheetContent(),
    ),
  );
}

// ─── Sheet content widget ─────────────────────────────────────────────────────

class _MoreSheetContent extends ConsumerWidget {
  const _MoreSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona = ref.watch(currentPersonaProvider);
    // Use ref.watch so the sheet reactively updates if auth state changes.
    final user = ref.watch(authNotifierProvider).valueOrNull;
    final navRoutes = personaNavConfig[persona]!.map((s) => s.route).toSet();
    final items = filterSheetDestinations(
      navRoutes: navRoutes,
      user: user,
      ref: ref,
    );
    final c = context.sac;

    return Semantics(
      label: 'nav.more_sheet_title'.tr(),
      child: Container(
        decoration: BoxDecoration(
          color: c.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // DraggableScrollableSheet constraints: min 30% screen, max 85%.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Title row ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'nav.more_sheet_title'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: 'common.close'.tr(),
                    button: true,
                    child: IconButton(
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: c.textSecondary,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'common.close'.tr(),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Items list ─────────────────────────────────────────────
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'common.no_results'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _MoreSheetTile(
                      item: item.dest,
                      resolvedRoute: item.resolvedRoute,
                    );
                  },
                ),
              ),

            // ── Safe-area bottom padding ───────────────────────────────
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}

// ─── Individual tile ──────────────────────────────────────────────────────────

class _MoreSheetTile extends StatelessWidget {
  final NavDestination item;
  final String resolvedRoute;

  const _MoreSheetTile({
    required this.item,
    required this.resolvedRoute,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveColor = item.color ?? c.text;

    return Semantics(
      button: true,
      label: item.labelKey.tr(),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          context.push(resolvedRoute);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: item.icon,
                    size: 20,
                    color: effectiveColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Label
              Expanded(
                child: Text(
                  item.labelKey.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.text,
                  ),
                ),
              ),
              // Chevron
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
