import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

import 'quick_access_items.dart';

/// Acceso rápido: 2×N de [SacCard] (well centrado + label).
///
/// Same surface as [ClubInfoCard]. Press scale, no [InkWell].
///
/// Watches the full [AsyncValue] from [authNotifierProvider] to distinguish
/// three states:
///   - loading  → show skeleton placeholders (avoids the flip-flop where
///                 `value == null` while the Future is still in flight)
///   - data with authorization → filter items by screen catalog and render grid
///   - data without authorization (genuinely empty) → SizedBox.shrink()
class QuickAccessGrid extends ConsumerWidget {
  const QuickAccessGrid({super.key, this.excludedRoutes = const {}});

  /// Rutas que no se pintan aunque el usuario tenga acceso (p. ej. el modo
  /// miembro del inicio ya muestra «Recursos» en «Para ti»).
  final Set<String> excludedRoutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authView = ref.watch(
      authNotifierProvider.select(
        (value) => (isLoading: value.isLoading, user: value.value),
      ),
    );

    // While the auth future is still resolving, show a placeholder that
    // occupies the same vertical space as the real grid would. This prevents
    // the layout from collapsing and then jumping when permissions arrive.
    if (authView.isLoading) {
      return const _QuickAccessSkeleton();
    }

    final user = authView.user;

    // Auth has settled but there is no authorization data — either the user
    // has no assigned role or the response genuinely had none. Hide the grid.
    // The provider also hides it when the membership is not operational.
    if (user?.authorization == null) {
      return const SizedBox.shrink();
    }

    final filteredItems = ref
        .watch(visibleQuickAccessItemsProvider)
        .where((item) => !excludedRoutes.contains(item.route))
        .toList();

    if (filteredItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('dashboard.quick_access.title'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          // shrinkWrap OK: filteredItems is permission-gated from a small
          // compile-time list. Lives inside SingleChildScrollView > Column —
          // intrinsic height is required.
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
            return _QuickAccessTile(item: item, resolvedRoute: item.route);
          },
        ),
      ],
    );
  }
}

/// Skeleton placeholder shown while auth is resolving.
///
/// Renders 4 card placeholders in a 2x2 layout so the page height stays
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
            borderRadius: BorderRadius.circular(AppTheme.radius2XS),
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
          itemBuilder: (_, __) => const _QuickAccessSkeletonTile(),
        ),
      ],
    );
  }
}

class _QuickAccessSkeletonTile extends StatelessWidget {
  const _QuickAccessSkeletonTile();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: SacCard(
        padding: EdgeInsets.zero,
        child: SizedBox.expand(),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final QuickAccessItem item;

  /// Pre-resolved navigation path (static route or resolved dynamic route).
  final String resolvedRoute;

  const _QuickAccessTile({required this.item, required this.resolvedRoute});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final effectiveColor = item.color ?? SacAccent.of(context).color;

    return SizedBox.expand(
      child: SacCard(
        onTap: () => context.push(resolvedRoute),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: HugeIcon(
                icon: item.icon,
                size: 24,
                color: effectiveColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr(item.labelKey),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
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
    );
  }
}
