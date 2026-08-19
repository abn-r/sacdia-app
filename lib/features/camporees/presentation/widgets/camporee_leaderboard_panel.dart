import 'dart:ui' show FontFeature;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_leaderboard.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_score_format.dart';

class CamporeeLeaderboardPanel extends StatelessWidget {
  final AsyncValue<CamporeeLeaderboard> leaderboardAsync;
  final VoidCallback onRetry;

  const CamporeeLeaderboardPanel({
    super.key,
    required this.leaderboardAsync,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'camporees.detail.leaderboard_title'.tr(),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'camporees.detail.leaderboard_subtitle'.tr(),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          leaderboardAsync.when(
            data: (leaderboard) {
              if (leaderboard.rows.isEmpty) {
                return _LeaderboardEmpty(
                  label: 'camporees.detail.leaderboard_empty'.tr(),
                );
              }
              return Column(
                children: [
                  for (final row in leaderboard.rows) _LeaderboardRowTile(row: row),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: SacLoading()),
            ),
            error: (_, __) => _LeaderboardRetry(
              label: 'camporees.detail.leaderboard_error'.tr(),
              onRetry: onRetry,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRowTile extends StatelessWidget {
  final CamporeeLeaderboardRow row;

  const _LeaderboardRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final club = row.clubName?.trim().isNotEmpty == true
        ? row.clubName!
        : 'camporees.detail.leaderboard_unknown_club'.tr();
    final section = row.sectionName?.trim().isNotEmpty == true
        ? row.sectionName!
        : 'camporees.detail.leaderboard_section_fallback'.tr(
            namedArgs: {'id': '${row.clubSectionId}'},
          );
    final awarded = formatCamporeeScoreNumber(row.totalAwardedPoints);
    final max = formatCamporeeScoreNumber(row.totalMaxPoints);
    final percent = formatCamporeeScoreNumber(row.percentage);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${row.rank}',
              style: TextStyle(
                color: c.text,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  club,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  section,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$awarded / $max',
                style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LeaderboardEmpty extends StatelessWidget {
  final String label;

  const _LeaderboardEmpty({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.borderLight),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAward01,
            size: 18,
            color: c.textTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRetry extends StatelessWidget {
  final String label;
  final VoidCallback onRetry;

  const _LeaderboardRetry({
    required this.label,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.error.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 18,
            color: c.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('common.retry'.tr()),
          ),
        ],
      ),
    );
  }
}
