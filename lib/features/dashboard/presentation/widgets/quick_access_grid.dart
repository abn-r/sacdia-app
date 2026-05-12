import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/nav/destinations.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';

/// Grid 2xN de acceso rápido a los módulos principales del sistema.
///
/// Watches the full [AsyncValue] from [authNotifierProvider] to distinguish
/// three states:
///   - loading  → show skeleton placeholders (avoids the flip-flop where
///                 `valueOrNull == null` while the Future is still in flight)
///   - data with authorization → filter items by permissions and render grid
///   - data without authorization (genuinely empty) → SizedBox.shrink()
class QuickAccessGrid extends ConsumerWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);

    // While the auth future is still resolving, show a placeholder that
    // occupies the same vertical space as the real grid would. This prevents
    // the layout from collapsing and then jumping when permissions arrive.
    if (authAsync.isLoading) {
      return const _QuickAccessSkeleton();
    }

    final user = authAsync.valueOrNull;
    final authorization = user?.authorization;

    // Auth has settled but there is no authorization data — either the user
    // has no assigned role or the response genuinely had none. Hide the grid.
    if (authorization == null) {
      return const SizedBox.shrink();
    }

    final filteredItems = appDestinations.where((item) {
      // Ungated items (no permissions AND no roles) are visible to every
      // authenticated user — used only when authorization is not a concern.
      if (item.requiredPermissions.isEmpty && item.requiredRoles.isEmpty) {
        return true;
      }
      if (item.requiredPermissions.isNotEmpty &&
          hasAnyPermission(user, item.requiredPermissions)) {
        return true;
      }
      if (item.requiredRoles.isNotEmpty &&
          hasAnyRole(user, item.requiredRoles)) {
        return true;
      }
      return false;
    }).where((item) {
      // For items with a dynamic routeResolver, hide the card when the
      // resolved route is null (context data not yet available or missing).
      if (item.routeResolver != null) {
        return item.routeResolver!(ref) != null;
      }
      return true;
    }).toList();

    if (filteredItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('dashboard.quick_access.title'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          // shrinkWrap OK: filteredItems is permission-gated from a compile-time
          // constant list (max ~8 items). Lives inside SingleChildScrollView >
          // Column — intrinsic height is required.
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: filteredItems.length,
          itemBuilder: (context, index) {
            final item = filteredItems[index];
            final resolvedRoute = item.routeResolver != null
                ? item.routeResolver!(ref)
                : item.route;
            // resolvedRoute is guaranteed non-null here: items with null
            // resolution were already filtered out above.
            return _QuickAccessTile(item: item, resolvedRoute: resolvedRoute!);
          },
        ),
      ],
    );
  }
}

/// Skeleton placeholder shown while auth is resolving.
///
/// Renders 4 shimmer-like boxes in a 2x2 layout so the page height stays
/// stable and the grid doesn't cause a layout jump when it appears.
class _QuickAccessSkeleton extends StatelessWidget {
  const _QuickAccessSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shimmerColor = c.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title placeholder
        Container(
          height: 16,
          width: 120,
          decoration: BoxDecoration(
            color: shimmerColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          // shrinkWrap OK: skeleton with exactly 4 placeholder tiles.
          // Lives inside SingleChildScrollView > Column — intrinsic height
          // is required and item count is compile-time constant.
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.2,
          ),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: shimmerColor,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final NavDestination item;

  /// Pre-resolved navigation path (static route or resolved dynamic route).
  final String resolvedRoute;

  // Shared BorderRadius to avoid repeated allocations on every build.
  static final _kTileRadius = BorderRadius.circular(16);

  const _QuickAccessTile({required this.item, required this.resolvedRoute});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveColor = item.color ?? c.text;

    return Material(
      color: c.surface,
      borderRadius: _kTileRadius,
      child: InkWell(
        borderRadius: _kTileRadius,
        onTap: () => context.push(resolvedRoute),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: _kTileRadius,
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: effectiveColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: item.icon,
                    size: 24,
                    color: effectiveColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(item.labelKey),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
