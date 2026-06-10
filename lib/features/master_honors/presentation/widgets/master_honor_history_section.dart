import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/master_honor_roadmap.dart';
import 'package:sacdia_app/features/master_honors/domain/entities/user_master_honor.dart';
import 'package:sacdia_app/features/master_honors/presentation/providers/master_honors_providers.dart';

import 'master_honor_badge.dart';
import 'master_honor_roadmap_grid.dart';

/// Strip horizontal de maestrías para la Tarjeta Virtual.
class MasterHonorBadgeStrip extends ConsumerWidget {
  final int? maxItems;

  const MasterHonorBadgeStrip({
    super.key,
    this.maxItems,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honorsAsync = ref.watch(userMasterHonorsProvider);

    return honorsAsync.when(
      loading: () => const _MasterHonorStripSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (honors) {
        if (honors.isEmpty) return const SizedBox.shrink();

        final visible = _orderedMasterHonors(honors);
        final limit = maxItems;
        final limited = limit == null || visible.length <= limit
            ? visible
            : visible.sublist(0, limit);

        return _MasterHonorStripContent(honors: limited);
      },
    );
  }
}

/// Resumen de maestrías en perfil, con el mismo patrón visual de Logros.
class MasterHonorHistorySection extends ConsumerWidget {
  final bool showHeader;

  const MasterHonorHistorySection({
    super.key,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roadmapAsync = ref.watch(userMasterHonorRoadmapProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: roadmapAsync.when(
        loading: () => _MasterHonorProfileSkeleton(
          key: const ValueKey('master-honor-profile-skeleton'),
          showHeader: showHeader,
        ),
        error: (_, __) => _MasterHonorProfileError(
          key: const ValueKey('master-honor-profile-error'),
          showHeader: showHeader,
          onRetry: () => ref.invalidate(userMasterHonorRoadmapProvider),
        ),
        data: (items) => _MasterHonorProfileSummary(
          key: const ValueKey('master-honor-profile-data'),
          items: items,
          showHeader: showHeader,
        ),
      ),
    );
  }
}

class _MasterHonorProfileSummary extends StatelessWidget {
  const _MasterHonorProfileSummary({
    super.key,
    required this.items,
    required this.showHeader,
  });

  final List<MasterHonorRoadmap> items;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final awardedItems = items.where((item) => item.isAwarded).toList();
    final totalAwarded = awardedItems.length;
    final label = totalAwarded == 1 ? 'Maestría' : 'Maestrías';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              'MAESTRÍAS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: context.sac.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$totalAwarded',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.sac.text,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: context.sac.textSecondary,
                  height: 1,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.push(RouteNames.homeMasterHonors),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.sac.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedGridView,
                    size: 18,
                    color: context.sac.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (awardedItems.isEmpty)
            Text(
              'Aún no tienes maestrías',
              style: TextStyle(
                fontSize: 13,
                color: context.sac.textTertiary,
              ),
            )
          else
            SizedBox(
              height: 52,
              child: GestureDetector(
                onTap: () => context.push(RouteNames.homeMasterHonors),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: awardedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = awardedItems[index];
                    return MasterHonorLogo(
                      imageUrl: item.masterImage,
                      name: item.name,
                      size: 44,
                      color: masterHonorAccentColor(item),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MasterHonorProfileError extends StatelessWidget {
  const _MasterHonorProfileError({
    super.key,
    required this.showHeader,
    required this.onRetry,
  });

  final bool showHeader;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Text(
              'MAESTRÍAS',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.2,
                color: context.sac.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAward01,
                size: 18,
                color: context.sac.textTertiary,
              ),
              const SizedBox(width: 8),
              Text(
                'No pudimos cargar tus maestrías',
                style: TextStyle(
                  fontSize: 13,
                  color: context.sac.textTertiary,
                ),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Reintentar',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.sac.info,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MasterHonorStripContent extends StatelessWidget {
  const _MasterHonorStripContent({required this.honors});

  final List<UserMasterHonor> honors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: honors
                .map(
                  (honor) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: MasterHonorBadge(
                      honor: honor,
                      compact: true,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _MasterHonorStripSkeleton extends StatelessWidget {
  const _MasterHonorStripSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(
          3,
          (index) => Container(
            width: 120,
            height: 54,
            decoration: BoxDecoration(
              color: _isDark(context)
                  ? AppColors.darkSurfaceVariant
                  : AppColors.lightSurfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _MasterHonorProfileSkeleton extends StatelessWidget {
  const _MasterHonorProfileSkeleton({
    super.key,
    required this.showHeader,
  });

  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            Container(
              width: 92,
              height: 12,
              decoration: BoxDecoration(
                color: context.sac.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Container(
                width: 40,
                height: 22,
                decoration: BoxDecoration(
                  color: context.sac.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 80,
                height: 14,
                decoration: BoxDecoration(
                  color: context.sac.surfaceVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: context.sac.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              5,
              (index) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.sac.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<UserMasterHonor> _orderedMasterHonors(List<UserMasterHonor> honors) {
  final ordered = List<UserMasterHonor>.from(honors)
    ..sort((a, b) {
      if (a.isCurrent != b.isCurrent) {
        return a.isCurrent ? -1 : 1;
      }

      final aDate = _latestDate(a);
      final bDate = _latestDate(b);

      if (aDate == null && bDate == null) {
        return a.name.compareTo(b.name);
      }
      if (aDate == null) return 1;
      if (bDate == null) return -1;

      return bDate.compareTo(aDate);
    });

  return ordered;
}

DateTime? _latestDate(UserMasterHonor honor) {
  final dates = [
    honor.awardedAt,
    honor.revokedAt,
    honor.recoveredAt,
  ].whereType<DateTime>().toList();
  if (dates.isEmpty) return null;
  return dates.reduce((a, b) => a.isAfter(b) ? a : b);
}

bool _isDark(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}
