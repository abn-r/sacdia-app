import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/investiture_history_cluster.dart';
import '../../domain/entities/investiture_history_entry.dart';
import '../providers/investiture_providers.dart';

/// Timeline of investiture actions for one enrollment.
class InvestitureHistoryView extends ConsumerWidget {
  final int enrollmentId;

  const InvestitureHistoryView({super.key, required this.enrollmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(investitureHistoryProvider(enrollmentId));

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        backgroundColor: AppColors.canvas,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'investiture.history.title'.tr(),
          style: const TextStyle(
            color: AppColors.ink900,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(investitureHistoryProvider(enrollmentId)),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 22,
              color: AppColors.ink900,
            ),
            tooltip: 'investiture.history.tooltip_refresh'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        child: historyAsync.when(
          data: (history) => _HistoryContent(history: history),
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _HistoryError(
            error: error,
            onRetry: () =>
                ref.invalidate(investitureHistoryProvider(enrollmentId)),
          ),
        ),
      ),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  final List<InvestitureHistoryEntry> history;

  const _HistoryContent({required this.history});

  @override
  Widget build(BuildContext context) {
    final hPad = Responsive.horizontalPadding(context);
    final clusters = clusterInvestitureHistory(history);
    final reduceMotion = SacMotion.reduceMotionOf(context);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (history.isEmpty)
                const _HistoryEmptyCard()
              else ...[
                _HistoryHeadline(history: history),
                const SizedBox(height: 20),
                StaggeredColumn(
                  animate: !reduceMotion,
                  children: [
                    for (var i = 0; i < clusters.length; i++)
                      _TimelineClusterTile(
                        cluster: clusters[i],
                        isLast: i == clusters.length - 1,
                      ),
                  ],
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _HistoryHeadline extends StatelessWidget {
  final List<InvestitureHistoryEntry> history;

  const _HistoryHeadline({required this.history});

  @override
  Widget build(BuildContext context) {
    final latest = latestInvestitureEntry(history)!;
    final showEstimate = switch (latest.action) {
      InvestitureAction.invested ||
      InvestitureAction.rejected ||
      InvestitureAction.expired =>
        false,
      _ => true,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _headline(latest.action),
          style: const TextStyle(
            color: AppColors.ink900,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.4,
          ),
        ),
        if (showEstimate) ...[
          const SizedBox(height: 6),
          Text(
            'investiture.history.estimated_time'.tr(),
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }

  String _headline(InvestitureAction action) {
    switch (action) {
      case InvestitureAction.invested:
        return 'investiture.history.headline_invested'.tr();
      case InvestitureAction.rejected:
        return 'investiture.history.headline_rejected'.tr();
      case InvestitureAction.expired:
        return action.label;
      default:
        return 'investiture.history.headline_in_review'.tr();
    }
  }
}

class _HistoryEmptyCard extends StatelessWidget {
  const _HistoryEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedClock01,
            size: 28,
            color: AppColors.ink400,
          ),
          const SizedBox(height: 12),
          Text(
            'investiture.history.empty_title'.tr(),
            style: const TextStyle(
              color: AppColors.ink900,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'investiture.history.empty_body'.tr(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _HistoryError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final msg = error.toString().replaceFirst('Exception: ', '');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 34,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'investiture.history.error_title'.tr(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink900,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              msg,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.ink500,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
              backgroundColor: AppColors.coral700,
              borderRadius: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineClusterTile extends StatelessWidget {
  final InvestitureHistoryCluster cluster;
  final bool isLast;

  const _TimelineClusterTile({
    required this.cluster,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final entry = cluster.representative;
    final color = _actionColor(entry.action);
    final comments = cluster.comments;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: _icon(entry.action),
                      size: 14,
                      color: color,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColors.ink150,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: const TextStyle(
                        color: AppColors.ink900,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.performerFullName} · ${_formatTime(entry.performedAt)}',
                      style: const TextStyle(
                        color: AppColors.ink500,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.25,
                      ),
                    ),
                    if (comments != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.only(left: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: AppColors.ink150,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Text(
                          comments,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.ink600,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _title {
    if (!cluster.isGrouped) return cluster.representative.action.label;
    final steps = cluster.entries.map((e) => e.action.shortLabel).join(' → ');
    return 'investiture.history.grouped_approvals'.tr(
      namedArgs: {'steps': steps},
    );
  }

  String _formatTime(DateTime at) {
    return DateFormat('d MMM · HH:mm').format(at.toLocal());
  }

  Color _actionColor(InvestitureAction action) {
    switch (action) {
      case InvestitureAction.submitted:
        return AppColors.sentDark;
      case InvestitureAction.clubApproved:
      case InvestitureAction.coordinatorApproved:
      case InvestitureAction.fieldApproved:
      case InvestitureAction.approved:
        return AppColors.validatedDark;
      case InvestitureAction.rejected:
        return AppColors.error;
      case InvestitureAction.invested:
        return AppColors.secondaryDark;
      case InvestitureAction.expired:
        return AppColors.observedDark;
      case InvestitureAction.reinvestitureRequested:
        return AppColors.coral700;
    }
  }

  List<List<dynamic>> _icon(InvestitureAction action) {
    switch (action) {
      case InvestitureAction.submitted:
        return HugeIcons.strokeRoundedSent;
      case InvestitureAction.clubApproved:
      case InvestitureAction.coordinatorApproved:
      case InvestitureAction.fieldApproved:
      case InvestitureAction.approved:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case InvestitureAction.rejected:
        return HugeIcons.strokeRoundedCancel01;
      case InvestitureAction.invested:
        return HugeIcons.strokeRoundedAward01;
      case InvestitureAction.expired:
        return HugeIcons.strokeRoundedAlert02;
      case InvestitureAction.reinvestitureRequested:
        return HugeIcons.strokeRoundedRefresh;
    }
  }
}
