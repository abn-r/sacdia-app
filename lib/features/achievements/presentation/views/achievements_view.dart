import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../domain/entities/user_achievement.dart';
import '../../domain/repositories/achievements_repository.dart';
import '../providers/achievements_providers.dart';
import '../widgets/achievement_grid_card.dart';
import 'achievement_detail_sheet.dart';

enum _AchievementFilter { all, unlocked, inProgress, locked }

/// Achievements screen v2 — summary hero, filters, badge grid with motion.
class AchievementsView extends ConsumerStatefulWidget {
  const AchievementsView({super.key});

  @override
  ConsumerState<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends ConsumerState<AchievementsView> {
  _AchievementFilter _filter = _AchievementFilter.all;
  bool _entrancePlayed = false;

  @override
  Widget build(BuildContext context) {
    final responseAsync = ref.watch(userAchievementsProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: responseAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, stack) => CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(context),
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(
                onRetry: () => ref.invalidate(userAchievementsProvider),
              ),
            ),
          ],
        ),
        data: (response) {
          final all = _flattenSorted(response);
          if (all.isEmpty) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(context),
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                ),
              ],
            );
          }

          final filtered = _applyFilter(all, _filter);
          final counts = _FilterCounts.from(all);

          if (!_entrancePlayed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_entrancePlayed) {
                setState(() => _entrancePlayed = true);
              }
            });
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: c.surface,
            edgeOffset: MediaQuery.paddingOf(context).top + 56,
            onRefresh: () async {
              ref.invalidate(userAchievementsProvider);
              await ref.read(userAchievementsProvider.future);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildAppBar(context),
                SliverToBoxAdapter(
                  child: _SummaryHeader(
                    completed: response.summary.totalCompleted,
                    total: all.length,
                    points: response.summary.totalPoints,
                    percentage: response.summary.completionPercentage,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _FilterBar(
                    filter: _filter,
                    counts: counts,
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _FilterEmptyState(
                      onClear: () =>
                          setState(() => _filter = _AchievementFilter.all),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.62,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filtered[index];
                          // Stagger only on first paint — filter/scroll must not re-play.
                          final delayMs = _entrancePlayed
                              ? 0
                              : (index.clamp(0, 11)) *
                                  SacMotion.stagger.inMilliseconds;
                          return AchievementGridCard(
                            key: ValueKey(item.achievement.achievementId),
                            achievementWithProgress: item,
                            animationDelay: Duration(milliseconds: delayMs),
                            animateEntrance: !_entrancePlayed,
                            onTap: () => _showDetailSheet(context, item),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    final c = context.sac;
    return SliverAppBar(
      pinned: true,
      floating: false,
      stretch: false,
      backgroundColor: c.background.withValues(alpha: 0.88),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      foregroundColor: c.text,
      centerTitle: true,
      title: Text(
        'achievements.views.title'.tr(),
        style: TextStyle(
          color: c.text,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
      ),
      leading: IconButton(
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowLeft01,
          color: c.text,
          size: 22,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(color: c.background.withValues(alpha: 0.72)),
        ),
      ),
    );
  }

  List<AchievementWithProgress> _flattenSorted(
    UserAchievementsResponse response,
  ) {
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

    all.sort((a, b) => rank(a).compareTo(rank(b)));
    return all;
  }

  List<AchievementWithProgress> _applyFilter(
    List<AchievementWithProgress> all,
    _AchievementFilter filter,
  ) {
    if (filter == _AchievementFilter.all) return all;
    return all.where((item) {
      final state =
          item.userAchievement?.visualState ?? AchievementVisualState.locked;
      return switch (filter) {
        _AchievementFilter.all => true,
        _AchievementFilter.unlocked => state == AchievementVisualState.unlocked,
        _AchievementFilter.inProgress =>
          state == AchievementVisualState.inProgress,
        _AchievementFilter.locked => state == AchievementVisualState.locked,
      };
    }).toList();
  }

  void _showDetailSheet(
    BuildContext context,
    AchievementWithProgress item,
  ) {
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
}

class _FilterCounts {
  final int all;
  final int unlocked;
  final int inProgress;
  final int locked;

  const _FilterCounts({
    required this.all,
    required this.unlocked,
    required this.inProgress,
    required this.locked,
  });

  factory _FilterCounts.from(List<AchievementWithProgress> items) {
    var unlocked = 0;
    var inProgress = 0;
    var locked = 0;
    for (final item in items) {
      final state =
          item.userAchievement?.visualState ?? AchievementVisualState.locked;
      switch (state) {
        case AchievementVisualState.unlocked:
          unlocked++;
        case AchievementVisualState.inProgress:
          inProgress++;
        case AchievementVisualState.locked:
          locked++;
      }
    }
    return _FilterCounts(
      all: items.length,
      unlocked: unlocked,
      inProgress: inProgress,
      locked: locked,
    );
  }
}

// ── Summary header ─────────────────────────────────────────────────────────────

class _SummaryHeader extends StatelessWidget {
  final int completed;
  final int total;
  final int points;
  final double percentage;

  const _SummaryHeader({
    required this.completed,
    required this.total,
    required this.points,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final progress = (percentage / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$completed',
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1,
                  letterSpacing: -1.2,
                  color: c.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 6),
                child: Text(
                  'achievements.views.summary_of'.tr(
                    namedArgs: {'total': '$total'},
                  ),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              if (points > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'achievements.views.summary_points'.tr(
                      namedArgs: {'points': '$points'},
                    ),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 5,
              child: Stack(
                children: [
                  Container(color: c.border),
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Filter bar ─────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final _AchievementFilter filter;
  final _FilterCounts counts;
  final ValueChanged<_AchievementFilter> onChanged;

  const _FilterBar({
    required this.filter,
    required this.counts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        children: [
          _FilterChip(
            label: 'achievements.views.filter_all'.tr(),
            count: counts.all,
            selected: filter == _AchievementFilter.all,
            onTap: () => onChanged(_AchievementFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'achievements.views.filter_unlocked'.tr(),
            count: counts.unlocked,
            selected: filter == _AchievementFilter.unlocked,
            onTap: () => onChanged(_AchievementFilter.unlocked),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'achievements.views.filter_in_progress'.tr(),
            count: counts.inProgress,
            selected: filter == _AchievementFilter.inProgress,
            onTap: () => onChanged(_AchievementFilter.inProgress),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'achievements.views.filter_locked'.tr(),
            count: counts.locked,
            selected: filter == _AchievementFilter.locked,
            onTap: () => onChanged(_AchievementFilter.locked),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final bg = widget.selected
        ? AppColors.primary.withValues(alpha: 0.14)
        : c.surfaceVariant.withValues(alpha: 0.7);
    final fg = widget.selected ? AppColors.primary : c.textSecondary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? 0.97 : 1,
        duration: SacMotion.press,
        curve: SacMotion.easeOut,
        child: AnimatedContainer(
          duration: SacMotion.standard,
          curve: SacMotion.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.selected
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : c.border.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      widget.selected ? FontWeight.w700 : FontWeight.w500,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.count}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fg.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Empty / error ──────────────────────────────────────────────────────────────

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

class _FilterEmptyState extends StatelessWidget {
  final VoidCallback onClear;

  const _FilterEmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedFilter,
              size: 40,
              color: context.sac.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'achievements.views.filter_empty'.tr(),
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClear,
              child: Text('achievements.views.filter_all'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

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
