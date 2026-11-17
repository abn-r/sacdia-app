import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/insurance_overview.dart';
import '../providers/insurance_actions_providers.dart';
import '../providers/insurance_providers.dart';
import '../utils/insurance_formatting.dart';
import '../widgets/insurance_action_sheet.dart';
import '../widgets/insurance_message_state.dart';
import '../widgets/insurance_skeleton.dart';
import '../widgets/insurance_ui.dart';

/// Reasignar: el seguro de quien dejó el club no se pierde. El director lo
/// pasa directo a alguien sin seguro; no pasa por el campo.
///
/// Sin [assignmentId] se usa el único seguro libre; con varios se listan para
/// elegir cuál pasar.
class ReassignInsuranceView extends ConsumerStatefulWidget {
  const ReassignInsuranceView({super.key, this.assignmentId});

  final int? assignmentId;

  @override
  ConsumerState<ReassignInsuranceView> createState() =>
      _ReassignInsuranceViewState();
}

class _ReassignInsuranceViewState extends ConsumerState<ReassignInsuranceView> {
  int? _assignmentId;
  String? _pickedUserId;

  @override
  void initState() {
    super.initState();
    _assignmentId = widget.assignmentId;
  }

  Future<void> _refresh() async {
    ref
      ..invalidate(insuranceOverviewProvider)
      ..invalidate(freeCoveragesProvider);
    try {
      await Future.wait([
        ref.read(insuranceOverviewProvider.future),
        ref.read(freeCoveragesProvider.future),
      ]);
    } catch (_) {
      // Painted from the provider state.
    }
  }

  Future<void> _reassign(FreeCoverage free, InsurancePerson to) async {
    final year = ref.read(insuranceOverviewProvider).value?.year?.label ?? '';
    final confirmed = await showInsuranceActionSheet(
      context,
      title:
          tr('insurance.reassign.confirm_title', namedArgs: {'name': to.name}),
      body: tr(
        'insurance.reassign.confirm_body',
        namedArgs: {
          'name': to.name,
          'year': year,
          'holder': free.holderName,
        },
      ),
      primaryLabel: tr('insurance.reassign.confirm_action'),
      secondaryLabel: tr('common.cancel'),
    );
    if (confirmed != true || !mounted) return;

    final ok =
        await ref.read(insuranceReassignNotifierProvider.notifier).submit(
              assignmentId: free.assignmentId,
              toUserId: to.userId,
            );
    if (!mounted) return;
    if (ok) {
      HapticFeedback.mediumImpact();
      SacSnackBar.show(
        context,
        tr('insurance.reassign.success', namedArgs: {'name': to.name}),
        isSuccess: true,
      );
      context.pushReplacement(RouteNames.homeInsurancePersonPath(to.userId));
    } else {
      final message = ref.read(insuranceReassignNotifierProvider).errorMessage;
      SacSnackBar.show(
        context,
        message ?? tr('insurance.reassign.error_generic'),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final access = ref.watch(insuranceAccessProvider);
    final overviewAsync = ref.watch(insuranceOverviewProvider);
    final freeAsync = ref.watch(freeCoveragesProvider);
    final busy = ref.watch(insuranceReassignNotifierProvider).isSubmitting;
    final overview = overviewAsync.value;
    final free = freeAsync.value;

    Widget body;
    if (access.isLoading ||
        (overview == null && overviewAsync.isLoading) ||
        (free == null && freeAsync.isLoading)) {
      body = const InsuranceSkeleton(rows: 4);
    } else if (!(access.value?.canReassign ?? false)) {
      body = InsuranceMessageState(
        title: tr('insurance.states.restricted_title'),
        body: tr('insurance.states.restricted_body'),
        icon: HugeIcons.strokeRoundedLockKey,
      );
    } else if (overview == null || free == null) {
      body = InsuranceMessageState.loadError(
        error: overviewAsync.error ?? freeAsync.error,
        onRetry: _refresh,
      );
    } else {
      body = _content(context, overview, free, busy);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('insurance.reassign.title'),
        backgroundColor: c.canvas,
        frosted: true,
        automaticallyImplyLeading: false,
        leading: SacPressable(
          listenOnly: true,
          child: IconButton(
            enableFeedback: false,
            tooltip: tr('common.close'),
            onPressed: () => Navigator.of(context).maybePop(),
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              color: c.text,
              size: 22,
            ),
          ),
        ),
      ),
      body: SacFrostedVeil(child: body),
    );
  }

  Widget _content(
    BuildContext context,
    InsuranceOverview overview,
    List<FreeCoverage> frees,
    bool busy,
  ) {
    final c = context.sac;
    if (frees.isEmpty) {
      return InsuranceMessageState(
        title: tr('insurance.reassign.none_title'),
        body: tr('insurance.reassign.none_body'),
        icon: HugeIcons.strokeRoundedShieldUser,
      );
    }

    FreeCoverage? free;
    final id = _assignmentId;
    if (id != null) {
      for (final f in frees) {
        if (f.assignmentId == id) free = f;
      }
    } else if (frees.length == 1) {
      free = frees.first;
    }

    // Several free insurances and none chosen: list them.
    if (free == null) {
      return ListView(
        padding: SacTopBar.paddingBelowBar(
          context,
          const EdgeInsets.only(top: 4, bottom: 32),
        ),
        children: [
          SacGroupedSection(
            key: const ValueKey('reassign-free-list'),
            label: tr('insurance.reassign.pick_free'),
            children: [
              for (final f in frees)
                InsuranceRow(
                  key: ValueKey('reassign-free-${f.assignmentId}'),
                  leading: InsuranceAvatar(name: f.holderName, muted: true),
                  title: f.holderName,
                  detail: _leftLine(context, f),
                  trailing: const InsuranceChevron(),
                  onTap: () => setState(() => _assignmentId = f.assignmentId),
                ),
            ],
          ),
        ],
      );
    }

    final candidates = overview.uninsured;
    final picked = candidates.where((p) => p.userId == _pickedUserId).isNotEmpty
        ? candidates.firstWhere((p) => p.userId == _pickedUserId)
        : (candidates.isEmpty ? null : candidates.first);
    final year = overview.year?.label ?? '';

    return Stack(
      children: [
        RefreshIndicator(
          color: SacAccent.of(context).color,
          edgeOffset: SacTopBar.frostedInset(context),
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.only(
                  top: 4, bottom: 32 + InsuranceFooter.height),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: SacSummaryBox(
                  color: c.surfaceVariant,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('insurance.reassign.free_label'),
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          InsuranceAvatar(name: free.holderName, muted: true),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  free.holderName,
                                  style: TextStyle(
                                    fontSize: SacFontSize.titleMedium,
                                    fontWeight: FontWeight.w600,
                                    color: c.text,
                                  ),
                                ),
                                Text(
                                  _leftLine(context, free),
                                  style: TextStyle(
                                    fontSize: SacFontSize.bodySmall,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Divider(height: 25, thickness: 1, color: c.border),
                      InsuranceBoxLine(
                        label: tr('insurance.issue.covers'),
                        value: tr(
                          'insurance.issue.covers_value',
                          namedArgs: {'year': year},
                        ),
                      ),
                      if (free.orderFolio != null) ...[
                        Divider(height: 25, thickness: 1, color: c.border),
                        InsuranceBoxLine(
                          label: tr('insurance.reassign.paid_in'),
                          value: free.orderFolio!,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (candidates.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Text(
                    tr('insurance.reassign.nobody'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      height: 1.45,
                      color: c.textSecondary,
                    ),
                  ),
                )
              else ...[
                SacGroupedSection(
                  key: const ValueKey('reassign-candidates'),
                  label: tr('insurance.reassign.to_whom'),
                  children: [
                    for (final p in candidates)
                      InsuranceRow(
                        key: ValueKey('reassign-person-${p.userId}'),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InsuranceRadio(
                                selected: p.userId == picked?.userId),
                            const SizedBox(width: 12),
                            InsuranceAvatar(name: p.name, imageUrl: p.picture),
                          ],
                        ),
                        title: p.name,
                        detail: insuranceRoleLine(p),
                        selected: p.userId == picked?.userId,
                        onTap: busy
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() => _pickedUserId = p.userId);
                              },
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Text(
                    tr('insurance.reassign.only_free_note'),
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      height: 1.4,
                      color: c.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (picked != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InsuranceFooter(
              button: SacButton.primary(
                key: const ValueKey('reassign-submit'),
                text: tr(
                  'insurance.reassign.submit',
                  namedArgs: {'name': picked.name.split(' ').first},
                ),
                icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
                isLoading: busy,
                onPressed: busy ? null : () => _reassign(free!, picked),
              ),
            ),
          ),
      ],
    );
  }

  String _leftLine(BuildContext context, FreeCoverage f) {
    final left = f.leftAt;
    return left == null
        ? tr('insurance.reassign.left_club')
        : tr(
            'insurance.reassign.left_club_on',
            namedArgs: {'date': insuranceShortDate(context, left)},
          );
  }
}
