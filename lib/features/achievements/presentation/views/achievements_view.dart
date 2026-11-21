import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/badge_grid/sac_badge_grid.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../providers/achievements_providers.dart';
import '../widgets/achievement_grid_card.dart';
import 'achievement_detail_sheet.dart';

/// Misma composición que Maestrías: barra esmerilada y grilla de tarjetas.
class AchievementsView extends ConsumerWidget {
  const AchievementsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final responseAsync = ref.watch(userAchievementsProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'achievements.views.title'.tr(),
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final top = SacTopBar.frostedInset(context);
            return responseAsync.when(
              // A refresh keeps the grid on screen so a card that was just
              // obtained can play its transition instead of being rebuilt.
              skipLoadingOnReload: true,
              loading: () => Padding(
                padding: EdgeInsets.only(top: top),
                child: const Center(child: SacLoading()),
              ),
              error: (_, __) => Padding(
                padding: EdgeInsets.only(top: top),
                child: SacErrorState(
                  title: 'achievements.views.error_title'.tr(),
                  message: 'achievements.views.error_subtitle'.tr(),
                  retryLabel: 'achievements.views.retry'.tr(),
                  onRetry: () => ref.invalidate(userAchievementsProvider),
                ),
              ),
              data: (response) {
                final items = flattenSortedAchievements(response);
                if (items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.only(top: top),
                    child: const _EmptyState(),
                  );
                }

                return RefreshIndicator(
                  color: SacAccent.of(context).color,
                  backgroundColor: c.surface,
                  edgeOffset: top,
                  onRefresh: () async {
                    ref.invalidate(userAchievementsProvider);
                    await ref.read(userAchievementsProvider.future);
                  },
                  child: SacBadgeGrid(
                    artHeight: kAchievementGridArtHeight,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(16, top, 16, 24),
                    itemCount: items.length,
                    keyOf: (index) =>
                        ValueKey(items[index].achievement.achievementId),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return AchievementGridCard(
                        achievementWithProgress: item,
                        onTap: () => _showDetail(context, item),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Every achievement in one list: obtained first, then in progress, then the
/// rest. The API order is kept inside each group.
List<AchievementWithProgress> flattenSortedAchievements(
    UserAchievementsResponse response) {
  final all =
      response.categories.expand((group) => group.achievements).toList();

  int rank(AchievementWithProgress item) {
    final state =
        item.userAchievement?.visualState ?? AchievementVisualState.locked;
    return switch (state) {
      AchievementVisualState.unlocked => 0,
      AchievementVisualState.inProgress => 1,
      AchievementVisualState.locked => 2,
    };
  }

  // Dart's sort is not guaranteed stable: break ties with the API position.
  final position = {for (var i = 0; i < all.length; i++) all[i]: i};
  all.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    return byRank != 0 ? byRank : position[a]!.compareTo(position[b]!);
  });
  return all;
}

void _showDetail(BuildContext context, AchievementWithProgress item) {
  showSacSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => AchievementDetailSheet(
      achievementWithProgress: item,
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return SacEmptyState(
      icon: HugeIcons.strokeRoundedAward01,
      title: 'achievements.views.empty_title'.tr(),
    );
  }
}
