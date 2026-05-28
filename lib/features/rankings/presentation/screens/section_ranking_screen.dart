import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../features/auth/domain/utils/authorization_utils.dart';
import '../../../../features/auth/presentation/providers/auth_providers.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/award_tier.dart';
import '../../domain/entities/member_ranking.dart';
import '../providers/section_ranking_provider.dart';
import '../widgets/member_ranking_list_tile.dart';
import '../widgets/ranking_empty_state.dart';
import '../widgets/ranking_skeleton.dart';

/// Pantalla de ranking de miembros clasificados dentro de una sección.
///
/// Importante: esta vista NO es el padrón completo de la sección; muestra las
/// filas existentes en `enrollment_rankings` para la sección/año seleccionados.
class SectionRankingScreen extends ConsumerWidget {
  const SectionRankingScreen({super.key, required this.sectionId});

  final int sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final ctxAsync = ref.watch(clubContextProvider);
    final authAsync = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              tr('rankings.section_ranking.title'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            yearAsync.maybeWhen(
              data: (year) => Text(
                year != null
                    ? tr('rankings.section_ranking.subtitle_with_year',
                        namedArgs: {'year': year.name})
                    : tr('rankings.section_ranking.subtitle'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
              orElse: () => Text(
                tr('rankings.section_ranking.subtitle'),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
            ),
          ],
        ),
        toolbarHeight: 60,
      ),
      body: yearAsync.when(
        data: (year) {
          if (year == null) {
            return const RankingEmptyState(reason: RankingEmptyReason.noData);
          }

          final ctx = ctxAsync.valueOrNull;
          final user = authAsync.valueOrNull;
          if (ctx == null || !canViewSectionRankings(user)) {
            if (ctxAsync.isLoading || authAsync.isLoading) {
              return RankingSkeleton.sectionList();
            }
            return const RankingEmptyState(
                reason: RankingEmptyReason.unauthorized);
          }

          return _SectionMembersList(
            sectionId: sectionId,
            yearId: year.ecclesiasticalYearId,
            yearName: year.name,
          );
        },
        loading: () => RankingSkeleton.sectionList(),
        error: (_, __) => RankingEmptyState(
          reason: RankingEmptyReason.networkError,
          onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
        ),
      ),
    );
  }
}

class _SectionMembersList extends ConsumerWidget {
  final int sectionId;
  final int yearId;
  final String yearName;

  const _SectionMembersList({
    required this.sectionId,
    required this.yearId,
    required this.yearName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = (sectionId: sectionId, yearId: yearId);
    final membersAsync = ref.watch(sectionMembersProvider(params));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(sectionMembersProvider(params)),
      child: membersAsync.when(
        data: (members) {
          if (members.isEmpty) {
            return const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: 500,
                child: RankingEmptyState(
                    reason: RankingEmptyReason.noSectionMembers),
              ),
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: members.length + 1,
            itemBuilder: (_, index) {
              if (index == 0) {
                return _SectionRankingHeader(
                  members: members,
                  yearName: yearName,
                );
              }

              final m = members[index - 1];
              return MemberRankingListTile(
                key: ValueKey(m.enrollmentId),
                rankPosition: m.rankPosition ?? index,
                memberName: m.memberName,
                sectionName: m.sectionName,
                compositeScore: m.compositeScorePct,
                awardedCategoryName: m.awardedCategory?.name,
                awardedCategoryTier:
                    m.awardedCategory?.tier ?? AwardTier.unknown,
                onTap: () => context.push(
                  RouteNames.memberBreakdownPath(m.enrollmentId, yearId),
                ),
              );
            },
          );
        },
        loading: () => RankingSkeleton.sectionList(),
        error: (_, __) => RankingEmptyState(
          reason: RankingEmptyReason.networkError,
          onRetry: () => ref.invalidate(sectionMembersProvider(params)),
        ),
      ),
    );
  }
}

class _SectionRankingHeader extends StatelessWidget {
  final List<MemberRanking> members;
  final String yearName;

  const _SectionRankingHeader({required this.members, required this.yearName});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final topScore = members
        .map((m) => m.compositeScorePct)
        .whereType<double>()
        .fold<double?>(
            null, (best, value) => best == null || value > best ? value : best);

    return Semantics(
      label: tr('rankings.section_ranking.header_semantics', namedArgs: {
        'count': members.length.toString(),
        'year': yearName,
      }),
      child: SacCard(
        margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        padding: const EdgeInsets.all(18),
        borderColor: AppColors.primary.withValues(alpha: 0.18),
        backgroundColor: c.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.leaderboard_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('rankings.section_ranking.ranked_members'),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: c.text,
                                  fontWeight: FontWeight.w800,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tr('rankings.section_ranking.explainer'),
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HeaderMetric(
                    label: tr('rankings.section_ranking.classified'),
                    value: members.length.toString(),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HeaderMetric(
                    label: tr('rankings.section_ranking.best_score'),
                    value: topScore == null ? '—' : topScore.toStringAsFixed(1),
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              tr('rankings.section_ranking.tap_hint'),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: c.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeaderMetric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
