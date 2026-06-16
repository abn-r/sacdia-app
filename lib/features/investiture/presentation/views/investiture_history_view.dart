import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/investiture_history_entry.dart';
import '../providers/investiture_providers.dart';

/// Vista de historial de acciones de investidura para un enrollment.
///
/// Muestra una línea de tiempo clara para que el miembro entienda quién envió,
/// quién revisó y en qué etapa está el proceso de investidura.
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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const _HistorySummaryCard(),
              const SizedBox(height: 22),
              if (history.isEmpty)
                const _HistoryEmptyCard()
              else ...[
                Text(
                  'investiture.history.timeline_title'.tr(),
                  style: const TextStyle(
                    color: AppColors.ink900,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 12),
                ...List.generate(history.length, (index) {
                  final entry = history[index];
                  return _TimelineEntry(
                    entry: entry,
                    isLast: index == history.length - 1,
                  );
                }),
              ],
            ]),
          ),
        ),
      ],
    );
  }
}

class _HistorySummaryCard extends StatelessWidget {
  const _HistorySummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.sentBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.sentColor.withValues(alpha: 0.22)),
      ),
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
                  color: AppColors.paper.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: AppColors.sentColor.withValues(alpha: 0.18),
                  ),
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedClock01,
                    size: 22,
                    color: AppColors.sentDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'investiture.history.summary_title'.tr(),
                      style: const TextStyle(
                        color: AppColors.ink900,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'investiture.history.summary_body'.tr(),
                      style: const TextStyle(
                        color: AppColors.ink600,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.paper.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.sentColor.withValues(alpha: 0.16),
              ),
            ),
            child: Row(
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar01,
                  size: 17,
                  color: AppColors.sentDark,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'investiture.history.estimated_time'.tr(),
                    style: const TextStyle(
                      color: AppColors.sentDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyCard extends StatelessWidget {
  const _HistoryEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.pendingBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedClock01,
                size: 25,
                color: AppColors.pendingDark,
              ),
            ),
          ),
          const SizedBox(height: 14),
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

class _TimelineEntry extends StatelessWidget {
  final InvestitureHistoryEntry entry;
  final bool isLast;

  const _TimelineEntry({required this.entry, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = _actionColor;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: color.withValues(alpha: 0.42)),
                  ),
                  child: Center(
                    child: HugeIcon(icon: _icon, size: 16, color: color),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: AppColors.ink150,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.paper,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.ink150),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink900.withValues(alpha: 0.035),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _actionLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusDot(color: color),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'investiture.history.performed_by'.tr(),
                      style: const TextStyle(
                        color: AppColors.ink400,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      entry.performerFullName,
                      style: const TextStyle(
                        color: AppColors.ink900,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (entry.performerRole != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.performerRole!,
                        style: const TextStyle(
                          color: AppColors.ink500,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          size: 13,
                          color: AppColors.ink400,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            DateFormat('d MMM yyyy · HH:mm')
                                .format(entry.performedAt.toLocal()),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.ink500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (entry.resultingStatus != null) ...[
                      const SizedBox(height: 10),
                      _ResultingStatusPill(
                          statusLabel: entry.resultingStatus!.label),
                    ],
                    if (entry.comments != null &&
                        entry.comments!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.canvas,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.ink150),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'investiture.history.comments_title'.tr(),
                              style: const TextStyle(
                                color: AppColors.ink400,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              entry.comments!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.ink600,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
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

  String get _actionLabel => entry.action.label;

  Color get _actionColor {
    switch (entry.action) {
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

  List<List<dynamic>> get _icon {
    switch (entry.action) {
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

class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Center(
        child: Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

class _ResultingStatusPill extends StatelessWidget {
  final String statusLabel;

  const _ResultingStatusPill({required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.pendingBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.ink150),
      ),
      child: Text(
        statusLabel,
        style: const TextStyle(
          color: AppColors.pendingDark,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
