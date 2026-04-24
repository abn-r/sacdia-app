import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/evidence_review_item.dart';
import '../providers/coordinator_providers.dart';
import '../widgets/evidence_review_card.dart';

/// Lista de evidencias pendientes de revisión con filtros por tipo.
///
/// Requiere GlobalRolesGuard (coordinator, admin) en el backend.
class EvidenceReviewListView extends ConsumerWidget {
  const EvidenceReviewListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeFilter = ref.watch(evidenceTypeFilterProvider);
    final evidenceAsync = ref.watch(pendingEvidenceProvider(activeFilter));
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text('coordinator.evidence_review.list.title'.tr()),
        actions: [
          IconButton(
            onPressed: () =>
                ref.invalidate(pendingEvidenceProvider(activeFilter)),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 22,
            ),
            tooltip: 'coordinator.evidence_review.list.refresh_tooltip'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filter chips ─────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
              child: _FilterChips(
                activeFilter: activeFilter,
                onFilterChanged: (type) {
                  ref.read(evidenceTypeFilterProvider.notifier).state = type;
                },
              ),
            ),

            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: evidenceAsync.when(
                data: (list) => _buildList(context, ref, list, hPad, c,
                    activeFilter),
                loading: () => const Center(child: SacLoading()),
                error: (error, _) => _buildError(context, ref, error,
                    activeFilter),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<EvidenceReviewItem> list,
    double hPad,
    SacColors c,
    EvidenceReviewType? activeFilter,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle01,
              size: 56,
              color: c.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'coordinator.evidence_review.list.no_pending'.tr(),
              style: TextStyle(fontSize: 16, color: c.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              activeFilter != null
                  ? 'coordinator.evidence_review.list.no_pending_type'
                      .tr(namedArgs: {'type': activeFilter.displayLabel.toLowerCase()})
                  : 'coordinator.evidence_review.list.all_up_to_date'.tr(),
              style: TextStyle(fontSize: 13, color: c.textTertiary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async =>
          ref.invalidate(pendingEvidenceProvider(activeFilter)),
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
        itemCount: list.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            final countKey = list.length == 1
                ? 'coordinator.evidence_review.list.count_one'
                : 'coordinator.evidence_review.list.count_other';
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedFolder01,
                    size: 16,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    countKey.tr(namedArgs: {'count': list.length.toString()}),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }
          final item = list[index - 1];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: EvidenceReviewCard(
              item: item,
              onTap: () => context.push(
                RouteNames.coordinatorEvidenceReviewDetail(
                  item.type.apiValue,
                  item.id,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    WidgetRef ref,
    Object error,
    EvidenceReviewType? activeFilter,
  ) {
    final c = context.sac;
    final msg = error.toString().replaceFirst('Exception: ', '');
    final is403 = msg.contains('permiso') || msg.contains('403');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: is403
                  ? HugeIcons.strokeRoundedLockKey
                  : HugeIcons.strokeRoundedAlert02,
              size: 56,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              is403
                  ? 'coordinator.evidence_review.list.access_restricted'.tr()
                  : 'coordinator.evidence_review.list.error_load'.tr(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              is403
                  ? 'coordinator.evidence_review.list.access_restricted_msg'.tr()
                  : msg,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (!is403) ...[
              const SizedBox(height: 24),
              SacButton.primary(
                text: 'coordinator.evidence_review.list.retry'.tr(),
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: () =>
                    ref.invalidate(pendingEvidenceProvider(activeFilter)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  final EvidenceReviewType? activeFilter;
  final ValueChanged<EvidenceReviewType?> onFilterChanged;

  const _FilterChips({
    required this.activeFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final filters = <({String label, EvidenceReviewType? value})>[
      (
        label: 'coordinator.evidence_review.list.filter_all'.tr(),
        value: null
      ),
      (
        label: 'coordinator.evidence_review.list.filter_folders'.tr(),
        value: EvidenceReviewType.folder
      ),
      (
        label: 'coordinator.evidence_review.list.filter_classes'.tr(),
        value: EvidenceReviewType.classType
      ),
      (
        label: 'coordinator.evidence_review.list.filter_honors'.tr(),
        value: EvidenceReviewType.honor
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = activeFilter == filter.value;
          return FilterChip(
            label: Text(filter.label),
            selected: isSelected,
            onSelected: (_) => onFilterChanged(filter.value),
            selectedColor: AppColors.primaryLight,
            checkmarkColor: AppColors.primary,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? AppColors.primary : null,
            ),
          );
        },
      ),
    );
  }
}
