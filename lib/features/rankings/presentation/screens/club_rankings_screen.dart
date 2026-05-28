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

class ClubRankingsScreen extends ConsumerWidget {
  const ClubRankingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authNotifierProvider);
    final ctxAsync = ref.watch(clubContextProvider);
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('rankings.annual_progress.title')),
      ),
      body: authAsync.when(
        data: (user) {
          if (!_canViewAnnualProgress(user)) {
            return const RankingEmptyState(
                reason: RankingEmptyReason.unauthorized);
          }

          return yearAsync.when(
            data: (year) {
              if (year == null) {
                return const RankingEmptyState(
                    reason: RankingEmptyReason.noData);
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
                loading: () => RankingSkeleton.myRanking(),
                error: (_, __) => RankingEmptyState(
                  reason: RankingEmptyReason.networkError,
                  onRetry: () => ref.invalidate(clubContextProvider),
                ),
              );
            },
            loading: () => RankingSkeleton.myRanking(),
            error: (_, __) => RankingEmptyState(
              reason: RankingEmptyReason.networkError,
              onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
            ),
          );
        },
        loading: () => RankingSkeleton.myRanking(),
        error: (_, __) => const RankingEmptyState(
          reason: RankingEmptyReason.unauthorized,
        ),
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
      loading: () => RankingSkeleton.myRanking(),
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
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _ProgressHeroCard(progress: progress, yearName: yearName),
          if (progress.nextTier != null)
            _NextTierCard(tier: progress.nextTier!)
          else
            const _TopTierCard(),
          _ComponentsCard(components: progress.components),
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

    return SacCard(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      padding: const EdgeInsets.all(18),
      borderColor: AppColors.primary.withValues(alpha: 0.18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedAward01,
                  size: 26,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('rankings.annual_progress.header_title'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w900,
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
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  _formatPoints(progress.currentPoints),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              _TierChip(label: progress.currentTier?.name),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tr(
              'rankings.annual_progress.points_of_total',
              namedArgs: {'total': _formatPoints(progress.maxPoints)},
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: percent,
              backgroundColor: c.surfaceVariant,
              color: AppColors.primary,
            ),
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
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String? label;

  const _TierChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final text = label?.trim().isNotEmpty == true
        ? label!.trim()
        : tr('rankings.annual_progress.no_tier_yet');

    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.secondaryDark,
              fontWeight: FontWeight.w800,
            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.accentLight,
      borderColor: AppColors.accent.withValues(alpha: 0.35),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const HugeIcon(
              icon: HugeIcons.strokeRoundedTarget01,
              size: 24,
              color: AppColors.accentDark,
            ),
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
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  tier.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.accentDark,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                if (pointsToReach != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    tr(
                      'rankings.annual_progress.points_to_reach',
                      namedArgs: {'points': _formatPoints(pointsToReach)},
                    ),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
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
    return SacCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      backgroundColor: AppColors.secondaryLight,
      borderColor: AppColors.secondary.withValues(alpha: 0.28),
      child: Text(
        tr('rankings.annual_progress.top_tier_reached'),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.secondaryDark,
              fontWeight: FontWeight.w800,
            ),
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
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: HugeIcons.strokeRoundedChartBarLine,
            title: tr('rankings.annual_progress.components_title'),
          ),
          const SizedBox(height: 14),
          for (final component in components) ...[
            _ComponentRow(component: component),
            if (component != components.last)
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

class _ComponentRow extends StatelessWidget {
  final RankingComponentProgress component;

  const _ComponentRow({required this.component});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final percent = (component.progressPercentage / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                component.label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text(
              tr(
                'rankings.annual_progress.component_points',
                namedArgs: {
                  'earned': _formatPoints(component.earnedPoints),
                  'max': _formatPoints(component.maxPoints),
                },
              ),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: percent,
            backgroundColor: c.surfaceVariant,
            color: AppColors.secondary,
          ),
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

    return SacCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeading(
            icon: HugeIcons.strokeRoundedTask01,
            title: tr('rankings.annual_progress.pending.title'),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Text(
              tr('rankings.annual_progress.pending.empty'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.35,
                  ),
            )
          else
            for (final item in items) ...[
              _PendingItemTile(item: item),
              if (item != items.last) const SizedBox(height: 10),
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

  const _SectionHeading({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      children: [
        HugeIcon(icon: icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }
}

String _formatPoints(int points) =>
    NumberFormat.decimalPattern().format(points);

String _formatDate(DateTime date) => DateFormat('dd/MM/yyyy').format(date);
