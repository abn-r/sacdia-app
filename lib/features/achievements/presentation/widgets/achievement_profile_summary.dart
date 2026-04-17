import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../providers/achievements_providers.dart';
import 'achievement_badge.dart';

/// YouVersion-style achievements section for the profile screen.
///
/// Layout:
///   - Header row: bold count + "Insignias" label on the left,
///     grid icon button on the right (navigates to full screen)
///   - Horizontal scrollable row of earned badge thumbnails (size 44)
///   - Tapping any badge or the grid icon → pushes to [RouteNames.homeAchievements]
///   - Shows "Aún no tienes insignias" if nothing is unlocked
class AchievementProfileSummary extends ConsumerWidget {
  const AchievementProfileSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responseAsync = ref.watch(userAchievementsProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: responseAsync.when(
        loading: () => _AchievementProfileSkeleton(
          key: const ValueKey('achievement-profile-skeleton'),
        ),
        error: (_, __) => const SizedBox.shrink(
          key: ValueKey('achievement-profile-error'),
        ),
        data: (response) => _AchievementProfileData(
          key: const ValueKey('achievement-profile-data'),
          response: response,
        ),
      ),
    );
  }
}

// ── Data widget ───────────────────────────────────────────────────────────────────

class _AchievementProfileData extends StatelessWidget {
  final UserAchievementsResponse response;

  const _AchievementProfileData({
    super.key,
    required this.response,
  });

  @override
  Widget build(BuildContext context) {
    // Collect only unlocked achievements, preserving category order
    final unlockedItems = response.categories
        .expand((group) => group.achievements)
        .where((item) => item.userAchievement?.isCompleted == true)
        .toList();

    final totalUnlocked = response.summary.totalCompleted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Bold count
              Text(
                '$totalUnlocked',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.sac.text,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              // Label
              Text(
                'Logros',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: context.sac.textSecondary,
                  height: 1,
                ),
              ),
              const Spacer(),
              // Grid icon button → achievements screen
              GestureDetector(
                onTap: () => context.push(RouteNames.homeAchievements),
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

          // ── Horizontal badge row ──────────────────────────────────
          if (unlockedItems.isEmpty)
            Text(
              'Aún no haz obtenido logros.',
              style: TextStyle(
                fontSize: 13,
                color: context.sac.textTertiary,
              ),
            )
          else
            SizedBox(
              height: 52, // badge 44 + ring overflow
              child: GestureDetector(
                onTap: () => context.push(RouteNames.homeAchievements),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: unlockedItems.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = unlockedItems[index];
                    final achievement = item.achievement;
                    final userAchievement = item.userAchievement;
                    final visualState = userAchievement?.visualState ??
                        AchievementVisualState.unlocked;

                    return AchievementBadge(
                      badgeImageUrl: achievement.badgeImageUrl,
                      tier: achievement.tier,
                      visualState: visualState,
                      isSecret: false,
                      size: 44,
                      progress: userAchievement?.progressPercentage ?? 1.0,
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

// ── Skeleton ───────────────────────────────────────────────────────────────────────

class _AchievementProfileSkeleton extends StatelessWidget {
  const _AchievementProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = context.sac.surfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              Container(
                height: 22,
                width: 40,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 14,
                width: 70,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Badge row skeleton — 5 circles
          Row(
            children: List.generate(5, (i) {
              return Padding(
                padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: skeletonColor,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
