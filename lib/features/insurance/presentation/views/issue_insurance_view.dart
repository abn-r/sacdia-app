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
import '../../../../core/utils/money_format.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/insurance_conflict.dart';
import '../../domain/entities/insurance_overview.dart';
import '../providers/insurance_actions_providers.dart';
import '../providers/insurance_providers.dart';
import '../utils/insurance_formatting.dart';
import '../widgets/insurance_action_sheet.dart';
import '../widgets/insurance_conflict_sheet.dart';
import '../widgets/insurance_message_state.dart';
import '../widgets/insurance_skeleton.dart';
import '../widgets/insurance_ui.dart';

/// Asegurar: quienes no tienen seguro vienen elegidos; quien ya tiene seguro
/// (aquí o en otra sección) o ya está en una orden aparece abajo, sin casilla
/// y con el motivo.
class IssueInsuranceView extends ConsumerStatefulWidget {
  const IssueInsuranceView({super.key});

  @override
  ConsumerState<IssueInsuranceView> createState() => _IssueInsuranceViewState();
}

class _IssueInsuranceViewState extends ConsumerState<IssueInsuranceView> {
  /// The people without insurance come selected: here live the ones the
  /// director took off.
  final Set<String> _deselected = {};

  Future<void> _refresh() async {
    ref.invalidate(insuranceOverviewProvider);
    try {
      await ref.read(insuranceOverviewProvider.future);
    } catch (_) {
      // Painted from the provider state.
    }
  }

  List<String> _selectedIds(InsuranceOverview overview) => [
        for (final p in overview.uninsured)
          if (!_deselected.contains(p.userId)) p.userId,
      ];

  Future<void> _issue(InsuranceOverview overview) async {
    final cycle = overview.cycle;
    if (cycle == null) return;
    final ids = _selectedIds(overview);
    if (ids.isEmpty) return;

    final total = SacMoney.fromCentavos(cycle.unitCostCentavos * ids.length);
    final deadline = cycle.purchaseDeadline;
    final confirmed = await showInsuranceActionSheet(
      context,
      title: tr('insurance.issue.confirm_title'),
      body: [
        'insurance.issue.confirm_body'
            .plural(ids.length, namedArgs: {'total': total}),
        if (deadline != null)
          tr(
            'insurance.issue.confirm_deadline',
            namedArgs: {'date': insuranceShortDate(context, deadline)},
          ),
        tr('insurance.issue.confirm_expiry'),
      ].join(' '),
      primaryLabel: tr('insurance.issue.confirm_action'),
      secondaryLabel: tr('common.cancel'),
    );
    if (confirmed != true || !mounted) return;
    await _submit(overview, ids);
  }

  Future<void> _submit(InsuranceOverview overview, List<String> ids) async {
    final cycle = overview.cycle;
    if (cycle == null) return;
    final notifier = ref.read(insuranceIssueNotifierProvider.notifier);
    final order = await notifier.submit(
      cycleConfigId: cycle.cycleConfigId,
      beneficiaryUserIds: ids,
    );
    if (!mounted) return;

    if (order != null) {
      HapticFeedback.mediumImpact();
      SacSnackBar.show(
        context,
        tr(
          'insurance.issue.success',
          namedArgs: {'folio': order.folioReference},
        ),
        isSuccess: true,
      );
      context.pushReplacement(RouteNames.paymentOrderDetailPath(order.orderId));
      return;
    }

    final state = ref.read(insuranceIssueNotifierProvider);
    if (state.conflicts.isNotEmpty) {
      await _handleConflicts(overview, ids, state.conflicts);
    } else if (state.errorMessage != null) {
      SacSnackBar.show(context, state.errorMessage!, isError: true);
    }
  }

  Future<void> _handleConflicts(
    InsuranceOverview overview,
    List<String> ids,
    List<InsuranceConflict> conflicts,
  ) async {
    final cycle = overview.cycle!;
    final blocked = conflicts.map((c) => c.userId).toSet();
    final remaining = ids.where((id) => !blocked.contains(id)).toList();
    final issueWithRest = await showInsuranceConflictSheet(
      context,
      conflicts: conflicts,
      remainingCount: remaining.length,
      remainingTotal:
          SacMoney.fromCentavos(cycle.unitCostCentavos * remaining.length),
    );
    if (!mounted) return;
    ref.read(insuranceIssueNotifierProvider.notifier).clearConflicts();
    if (issueWithRest == true && remaining.isNotEmpty) {
      await _submit(overview, remaining);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final overviewAsync = ref.watch(insuranceOverviewProvider);
    final access =
        ref.watch(insuranceAccessProvider).value ?? InsuranceAccess.readOnly;
    final accessLoading = ref.watch(insuranceAccessProvider).isLoading;
    final issue = ref.watch(insuranceIssueNotifierProvider);
    final overview = overviewAsync.value;

    Widget body;
    if (accessLoading || (overview == null && overviewAsync.isLoading)) {
      body = const InsuranceSkeleton(rows: 4);
    } else if (!access.canIssue) {
      body = InsuranceMessageState(
        title: tr('insurance.states.restricted_title'),
        body: tr('insurance.states.restricted_body'),
        icon: HugeIcons.strokeRoundedLockKey,
      );
    } else if (overview == null && overviewAsync.hasError) {
      body = InsuranceMessageState.loadError(
        error: overviewAsync.error,
        onRetry: _refresh,
      );
    } else if (overview == null || overview.cycle == null) {
      body = InsuranceMessageState(
        title: tr(
          'insurance.states.no_cost_title',
          namedArgs: {'year': overview?.year?.label ?? ''},
        ),
        body: tr('insurance.states.no_cost_body'),
        icon: HugeIcons.strokeRoundedCalendar03,
      );
    } else {
      body = _Form(
        overview: overview,
        deselected: _deselected,
        busy: issue.isSubmitting,
        onToggle: (id) => setState(() {
          if (!_deselected.remove(id)) _deselected.add(id);
        }),
        onToggleAll: () => setState(() {
          final all = overview.uninsured.map((p) => p.userId);
          if (_deselected.isEmpty) {
            _deselected.addAll(all);
          } else {
            _deselected.clear();
          }
        }),
        onIssue: () => _issue(overview),
        onRefresh: _refresh,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('insurance.issue.title'),
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
}

class _Form extends StatelessWidget {
  const _Form({
    required this.overview,
    required this.deselected,
    required this.busy,
    required this.onToggle,
    required this.onToggleAll,
    required this.onIssue,
    required this.onRefresh,
  });

  final InsuranceOverview overview;
  final Set<String> deselected;
  final bool busy;
  final ValueChanged<String> onToggle;
  final VoidCallback onToggleAll;
  final VoidCallback onIssue;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final cycle = overview.cycle!;
    final year = overview.year?.label ?? '';
    final uninsured = overview.uninsured;
    final blocked = overview.blocked;
    final selected =
        uninsured.where((p) => !deselected.contains(p.userId)).length;
    final total = SacMoney.fromCentavos(cycle.unitCostCentavos * selected);
    final allSelected = selected == uninsured.length;

    return Stack(
      children: [
        RefreshIndicator(
          color: SacAccent.of(context).color,
          edgeOffset: SacTopBar.frostedInset(context),
          onRefresh: onRefresh,
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
                    children: [
                      InsuranceBoxLine(
                        label: tr('insurance.issue.insurance'),
                        value: tr(
                          'insurance.issue.annual',
                          namedArgs: {'year': year},
                        ),
                      ),
                      Divider(height: 25, thickness: 1, color: c.border),
                      InsuranceBoxLine(
                        label: tr('insurance.summary.unit_cost'),
                        value: SacMoney.fromCentavos(cycle.unitCostCentavos),
                      ),
                      Divider(height: 25, thickness: 1, color: c.border),
                      InsuranceBoxLine(
                        label: tr('insurance.issue.covers'),
                        value: tr(
                          'insurance.issue.covers_value',
                          namedArgs: {'year': year},
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (uninsured.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                  child: Text(
                    tr('insurance.issue.nobody_left'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: SacFontSize.titleSmall,
                      height: 1.45,
                      color: c.textSecondary,
                    ),
                  ),
                )
              else
                SacGroupedSection(
                  key: const ValueKey('issue-uninsured'),
                  label: tr('insurance.issue.uninsured_title'),
                  count: uninsured.length,
                  action: InsuranceEyebrowAction(
                    label: tr(
                      allSelected
                          ? 'insurance.issue.select_none'
                          : 'insurance.issue.select_all',
                    ),
                    onTap: onToggleAll,
                  ),
                  children: [
                    for (final p in uninsured)
                      InsuranceRow(
                        key: ValueKey('issue-person-${p.userId}'),
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InsuranceSelectBox(
                              selected: !deselected.contains(p.userId),
                            ),
                            const SizedBox(width: 12),
                            InsuranceAvatar(name: p.name, imageUrl: p.picture),
                          ],
                        ),
                        title: p.name,
                        detail: insuranceRoleLine(p),
                        selected: !deselected.contains(p.userId),
                        semanticLabel: tr(
                          'insurance.issue.select_person',
                          namedArgs: {'name': p.name},
                        ),
                        onTap: busy
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                onToggle(p.userId);
                              },
                      ),
                  ],
                ),
              if (blocked.isNotEmpty)
                SacGroupedSection(
                  key: const ValueKey('issue-blocked'),
                  label: tr('insurance.issue.blocked_title'),
                  children: [
                    for (final p in blocked)
                      InsuranceRow(
                        key: ValueKey('issue-blocked-${p.userId}'),
                        leading: InsuranceAvatar(
                          name: p.name,
                          imageUrl: p.picture,
                          muted: true,
                        ),
                        title: p.name,
                        titleMuted: true,
                        detail: _blockedReason(context, p),
                        trailing: InsuranceStatusChip(status: p.status),
                        semanticLabel: '${p.name}, '
                            '${insuranceStatusLabel(p.status)}, '
                            '${_blockedReason(context, p)}',
                      ),
                  ],
                ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: InsuranceFooter(
            button: SacButton.primary(
              key: const ValueKey('issue-submit'),
              text: tr(
                'insurance.issue.submit',
                namedArgs: {
                  'people': 'insurance.issue.people'.plural(selected),
                  'total': total,
                },
              ),
              isEnabled: selected > 0 && !busy,
              isLoading: busy,
              onPressed: onIssue,
            ),
            note: tr('insurance.issue.footer_note'),
          ),
        ),
      ],
    );
  }

  String _blockedReason(BuildContext context, InsurancePerson p) {
    if (p.status != InsurancePersonStatus.covered) {
      return insuranceDetail(context, p);
    }
    final coverage = p.coverage;
    switch (coverage?.source) {
      case CoverageSource.paidElsewhere:
        final place = coverage?.paidInSectionName ?? coverage?.paidInClubName;
        return place == null
            ? tr('insurance.issue.reason_covered')
            : tr('insurance.issue.reason_covered_in',
                namedArgs: {'place': place});
      case CoverageSource.reassigned:
        return tr('insurance.issue.reason_reassigned');
      case CoverageSource.paidHere:
      case null:
        return tr('insurance.issue.reason_covered');
    }
  }
}
