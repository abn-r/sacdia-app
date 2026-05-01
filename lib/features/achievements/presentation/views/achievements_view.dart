import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/repositories/achievements_repository.dart';
import '../providers/achievements_providers.dart';
import '../widgets/achievement_grid_card.dart';
import 'achievement_detail_sheet.dart';

/// Full achievements screen — YouVersion badge grid layout.
///
/// - Dark scaffold background
/// - AppBar: back arrow + "Logros" centered
/// - Body: flat 3-column GridView of all achievements (no category grouping)
/// - Pull-to-refresh
/// - Loading / error / empty states
class AchievementsView extends ConsumerWidget {
  const AchievementsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responseAsync = ref.watch(userAchievementsProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: context.sac.text,
        centerTitle: true,
        title: Text(
          'achievements.views.title'.tr(),
          style: TextStyle(
            color: context.sac.text,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: context.sac.text, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: responseAsync.when(
        loading: () => const Center(
          child: SacLoading(),
        ),
        error: (error, stack) => _ErrorState(
          onRetry: () => ref.invalidate(userAchievementsProvider),
        ),
        data: (response) {
          // Flatten all achievements from all categories into a single list
          final allAchievements = response.categories
              .expand((group) => group.achievements)
              .toList();

          if (allAchievements.isEmpty) {
            return const _EmptyState();
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: context.sac.surface,
            onRefresh: () async {
              ref.invalidate(userAchievementsProvider);
              await ref.read(userAchievementsProvider.future);
            },
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // Enough vertical space: badge 64 + counter + name 2 lines + bar
                childAspectRatio: 0.72,
              ),
              itemCount: allAchievements.length,
              itemBuilder: (context, index) {
                final item = allAchievements[index];
                return AchievementGridCard(
                  achievementWithProgress: item,
                  onTap: () => _showDetailSheet(context, item, ref),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    AchievementWithProgress item,
    WidgetRef ref,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AchievementDetailSheet(
        achievementWithProgress: item,
      ),
    );
  }
}

// ── Empty State ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 64,
              color: context.sac.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'achievements.views.empty_title'.tr(),
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error State ──────────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'achievements.views.error_title'.tr(),
              style: TextStyle(
                color: context.sac.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'achievements.views.error_subtitle'.tr(),
              style: TextStyle(color: context.sac.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'achievements.views.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
