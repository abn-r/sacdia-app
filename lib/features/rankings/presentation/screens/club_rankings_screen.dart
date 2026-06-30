import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../../features/auth/domain/utils/authorization_utils.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../features/members/presentation/providers/members_providers.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../domain/entities/annual_ranking_progress.dart';
import '../providers/annual_ranking_progress_provider.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

class ClubRankingsScreen extends ConsumerWidget {
  const ClubRankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authView = ref.watch(
      authNotifierProvider.select(
        (value) => (
          isLoading: value.isLoading,
          hasError: value.hasError,
          user: value.valueOrNull,
        ),
      ),
    );
    final ctxAsync = ref.watch(clubContextProvider);
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text(tr('rankings.annual_progress.title')),
      ),
      body: Builder(
        builder: (context) {
          if (authView.isLoading) {
            return RankingSkeleton.annualProgress();
          }
          if (authView.hasError || !_canViewAnnualProgress(authView.user)) {
            return const RankingEmptyState(
              reason: RankingEmptyReason.unauthorized,
            );
          }

          return yearAsync.when(
            data: (year) {
              if (year == null) {
                return const RankingEmptyState(
                  reason: RankingEmptyReason.noData,
                );
              }

              return ctxAsync.when(
                data: (ctx) {
                  if (ctx == null) {
                    return const RankingEmptyState(
                      reason: RankingEmptyReason.unauthorized,
                    );
                  }

                  return _AnnualRankingProgressBody(
                    sectionId: ctx.sectionId,
                    yearId: year.ecclesiasticalYearId,
                    yearName: year.name,
                  );
                },
                loading: () => RankingSkeleton.annualProgress(),
                error: (_, __) => RankingEmptyState(
                  reason: RankingEmptyReason.networkError,
                  onRetry: () => ref.invalidate(clubContextProvider),
                ),
              );
            },
            loading: () => RankingSkeleton.annualProgress(),
            error: (_, __) => RankingEmptyState(
              reason: RankingEmptyReason.networkError,
              onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
            ),
          );
        },
      ),
    );
  }
}

bool _canViewAnnualProgress(UserEntity? user) {
  return canViewClubRankings(user) || canViewSectionRankings(user);
}

class _AnnualRankingProgressBody extends ConsumerWidget {
  final int sectionId;
  final int yearId;
  final String yearName;

  const _AnnualRankingProgressBody({
    required this.sectionId,
    required this.yearId,
    required this.yearName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (sectionId: sectionId, yearId: yearId);
    final progressAsync = ref.watch(annualRankingProgressProvider(params));

    return progressAsync.when(
      data: (progress) => AnnualRankingProgressContent(
        progress: progress,
        yearName: yearName,
        onRefresh: () async =>
            ref.invalidate(annualRankingProgressProvider(params)),
      ),
      loading: () => RankingSkeleton.annualProgress(),
      error: (_, __) => RankingEmptyState(
        reason: RankingEmptyReason.networkError,
        onRetry: () => ref.invalidate(annualRankingProgressProvider(params)),
      ),
    );
  }
}

class AnnualRankingProgressContent extends StatelessWidget {
  final AnnualRankingProgress progress;
  final String yearName;
  final Future<void> Function() onRefresh;

  const AnnualRankingProgressContent({
    super.key,
    required this.progress,
    required this.yearName,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          _ProgressHeroCard(progress: progress, yearName: yearName),
          const SizedBox(height: 12),
          if (progress.nextTier != null)
            _NextTierCard(tier: progress.nextTier!)
          else
            const _TopTierCard(),
          const SizedBox(height: 12),
          if (progress.axes.isNotEmpty)
            _AxesCard(axes: progress.axes)
          else
            _ComponentsCard(components: progress.components),
          const SizedBox(height: 12),
          _PendingItemsCard(items: progress.pendingItems),
        ],
      ),
    );
  }
}

class _ProgressHeroCard extends StatelessWidget {
  final AnnualRankingProgress progress;
  final String yearName;

  const _ProgressHeroCard({required this.progress, required this.yearName});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = (progress.progressPercentage / 100).clamp(0.0, 1.0);
    final tierPalette = _tierPaletteFor(context, progress.currentTier);

    return Semantics(
      label:
          '${tr('rankings.annual_progress.header_title')}, ${_formatPoints(progress.currentPoints)} ${tr('rankings.annual_progress.points_of_total', namedArgs: {
            'total': _formatPoints(progress.maxPoints),
          })}, ${tr('rankings.annual_progress.progress_percentage', namedArgs: {
            'percent': progress.progressPercentage.toStringAsFixed(0),
          })}',
      child: SacCard(
        padding: const EdgeInsets.all(18),
        borderColor: AppColors.primary.withValues(alpha: 0.18),
        backgroundColor: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconTile(
                  icon: HugeIcons.strokeRoundedAward01,
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySurface,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('rankings.annual_progress.header_title'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr(
                          'rankings.annual_progress.header_body',
                          namedArgs: {
                            'club': progress.clubName,
                            'type': progress.clubType.name,
                            'year': yearName,
                          },
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                              height: 1.35,
                            ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatPoints(progress.currentPoints),
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 34,
                                  letterSpacing: -0.8,
                                  height: 0.95,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(
                          'rankings.annual_progress.points_of_total',
                          namedArgs: {
                            'total': _formatPoints(progress.maxPoints),
                          },
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _TierChip(
                  label: progress.currentTier?.name,
                  palette: tierPalette,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _AnimatedProgressBar(
              value: percent,
              color: _progressColorFor(percent, c),
              backgroundColor: c.surfaceVariant,
              height: 10,
            ),
            const SizedBox(height: 8),
            Text(
              tr(
                'rankings.annual_progress.progress_percentage',
                namedArgs: {
                  'percent': progress.progressPercentage.toStringAsFixed(0),
                },
              ),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String? label;
  final _TierPalette palette;

  const _TierChip({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    final text = label?.trim().isNotEmpty == true
        ? label!.trim()
        : tr('rankings.annual_progress.no_tier_yet');

    return Container(
      constraints: const BoxConstraints(minHeight: 38, minWidth: 86),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: palette.foreground,
              fontWeight: FontWeight.w900,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _NextTierCard extends StatelessWidget {
  final RankingTier tier;

  const _NextTierCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pointsToReach = tier.pointsToReach;

    return SacCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Color.lerp(c.surface, AppColors.accentLight, 0.62),
      borderColor: AppColors.accent.withValues(alpha: 0.32),
      accentColor: AppColors.accent,
      child: Row(
        children: [
          _IconTile(
            icon: HugeIcons.strokeRoundedTarget01,
            color: AppColors.accentDark,
            backgroundColor: c.surface.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('rankings.annual_progress.next_tier'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: c.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  tier.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accentDark,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                ),
                if (pointsToReach != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    tr(
                      'rankings.annual_progress.points_to_reach',
                      namedArgs: {'points': _formatPoints(pointsToReach)},
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTierCard extends StatelessWidget {
  const _TopTierCard();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      padding: const EdgeInsets.all(16),
      backgroundColor: Color.lerp(c.surface, AppColors.secondaryLight, 0.68),
      borderColor: AppColors.secondary.withValues(alpha: 0.28),
      accentColor: AppColors.secondary,
      child: Row(
        children: [
          _IconTile(
            icon: HugeIcons.strokeRoundedAward01,
            color: AppColors.secondaryDark,
            backgroundColor: c.surface.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tr('rankings.annual_progress.top_tier_reached'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.secondaryDark,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComponentsCard extends StatelessWidget {
  final List<RankingComponentProgress> components;

  const _ComponentsCard({required this.components});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: HugeIcons.strokeRoundedChartBarLine,
            title: tr('rankings.annual_progress.components_title'),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < components.length; index++) ...[
            _ComponentRow(component: components[index]),
            if (index != components.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, color: c.divider),
              ),
          ],
        ],
      ),
    );
  }
}

class _AxesCard extends StatelessWidget {
  final List<RankingAxisProgress> axes;

  const _AxesCard({required this.axes});

  @override
  Widget build(BuildContext context) {
    return SacCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: HugeIcons.strokeRoundedChartBarLine,
            title: tr('rankings.annual_progress.components_title'),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < axes.length; index++) ...[
            _AxisSection(axis: axes[index]),
            if (index != axes.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _AxisSection extends StatelessWidget {
  final RankingAxisProgress axis;

  const _AxisSection({required this.axis});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = (axis.progressPercentage / 100).clamp(0.0, 1.0);
    final accent = _axisAccentFor(axis.key);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedChartBarLine,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      axis.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w900,
                            height: 1.18,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'rankings.annual_progress.component_points',
                        namedArgs: {
                          'earned': _formatPoints(axis.earnedPoints),
                          'max': _formatPoints(axis.maxPoints),
                        },
                      ),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AnimatedProgressBar(
            value: percent,
            backgroundColor: c.surface,
            color: _progressColorFor(percent, c, activeColor: accent),
            height: 8,
          ),
          if (axis.components.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.borderLight),
              ),
              child: Column(
                children: [
                  for (var index = 0;
                      index < axis.components.length;
                      index++) ...[
                    _ComponentRow(component: axis.components[index]),
                    if (index != axis.components.length - 1)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: c.divider),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ComponentRow extends StatelessWidget {
  final RankingComponentProgress component;

  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = (component.progressPercentage / 100).clamp(0.0, 1.0);
    final color = _progressColorFor(percent, c, activeColor: AppColors.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                component.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              tr(
                'rankings.annual_progress.component_points',
                namedArgs: {
                  'earned': _formatPoints(component.earnedPoints),
                  'max': _formatPoints(component.maxPoints),
                },
              ),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _AnimatedProgressBar(
          value: percent,
          backgroundColor: c.surfaceVariant,
          color: color,
          height: 8,
        ),
      ],
    );
  }
}

class _PendingItemsCard extends StatelessWidget {
  final List<RankingPendingItem> items;

  const _PendingItemsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasItems = items.isNotEmpty;

    return SacCard(
      padding: const EdgeInsets.all(16),
      borderColor: hasItems
          ? AppColors.primary.withValues(alpha: 0.20)
          : AppColors.secondary.withValues(alpha: 0.22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: HugeIcons.strokeRoundedTask01,
            title: tr('rankings.annual_progress.pending.title'),
            color: hasItems ? AppColors.primary : AppColors.secondary,
          ),
          const SizedBox(height: 12),
          if (!hasItems)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.secondaryLight.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                tr('rankings.annual_progress.pending.empty'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
              ),
            )
          else
            for (var index = 0; index < items.length; index++) ...[
              _PendingItemTile(item: items[index]),
              if (index != items.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _PendingItemTile extends StatelessWidget {
  final RankingPendingItem item;

  const _PendingItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              _StatusChip(label: tr(item.statusLabelKey)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetaPill(
                icon: HugeIcons.strokeRoundedArrowRight01,
                label: item.actionLabel,
              ),
              if (item.dueDate != null)
                _MetaPill(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  label: tr(
                    'rankings.annual_progress.pending.due_date',
                    namedArgs: {'date': _formatDate(item.dueDate!)},
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;

  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;

  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 15, color: c.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final Color color;

  const _SectionHeading({
    required this.icon,
    required this.title,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            borderRadius: BorderRadius.circular(12),
          ),
          child: HugeIcon(icon: icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final Color backgroundColor;

  const _IconTile({
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: HugeIcon(icon: icon, size: 24, color: color),
    );
  }
}

class _AnimatedProgressBar extends StatelessWidget {
  final double value;
  final Color color;
  final Color backgroundColor;
  final double height;

  const _AnimatedProgressBar({
    required this.value,
    required this.color,
    required this.backgroundColor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final safeValue = value.clamp(0.0, 1.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: safeValue),
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
        builder: (context, animatedValue, _) {
          return LinearProgressIndicator(
            minHeight: height,
            value: animatedValue,
            backgroundColor: backgroundColor,
            color: color,
          );
        },
      ),
    );
  }
}

class _TierPalette {
  final Color foreground;
  final Color background;
  final Color border;

  const _TierPalette({
    required this.foreground,
    required this.background,
    required this.border,
  });
}

_TierPalette _tierPaletteFor(BuildContext context, RankingTier? tier) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final key = (tier?.slug ?? tier?.name ?? '').toLowerCase();

  final Color foreground = switch (key) {
    String value when value.contains('bronze') || value.contains('bronce') =>
      const Color(0xFFB86A2D),
    String value when value.contains('silver') || value.contains('plata') =>
      const Color(0xFF64748B),
    String value when value.contains('gold') || value.contains('oro') =>
      const Color(0xFF9A6B18),
    String value when value.contains('diamond') || value.contains('diamante') =>
      const Color(0xFF0E7490),
    _ => AppColors.secondaryDark,
  };

  return _TierPalette(
    foreground: foreground,
    background: isDark
        ? foreground.withValues(alpha: 0.18)
        : foreground.withValues(alpha: 0.12),
    border: foreground.withValues(alpha: isDark ? 0.36 : 0.20),
  );
}

Color _axisAccentFor(String key) {
  final normalized = key.toLowerCase();
  if (normalized.contains('oper')) return AppColors.secondary;
  if (normalized.contains('admin')) return AppColors.primary;
  return AppColors.accentDark;
}

Color _progressColorFor(
  double percent,
  SacColors colors, {
  Color activeColor = AppColors.primary,
}) {
  if (percent >= 1.0) return AppColors.secondary;
  if (percent <= 0.0) return colors.textTertiary;
  return activeColor;
}

String _formatPoints(int points) =>
    NumberFormat.decimalPattern().format(points);

String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
