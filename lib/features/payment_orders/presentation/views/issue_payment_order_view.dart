import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/insurance/domain/entities/member_insurance.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/widgets/insurance_status_badge.dart';

import '../../../camporees/presentation/providers/camporees_providers.dart';
import '../../domain/entities/payment_order.dart';
import '../../domain/utils/payment_order_eligibility.dart';
import '../providers/payment_orders_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Flujo de emisión de una orden de pago territorial.
///
/// - [PaymentOrderPurpose.insurance]: selecciona miembros SIN cobertura activa
///   del ciclo aplicable y emite la orden de seguro.
/// - [PaymentOrderPurpose.camporee]: selecciona miembros con seguro activo y
///   emite la orden de inscripción al camporee [camporeeId].
class IssuePaymentOrderView extends ConsumerWidget {
  final PaymentOrderPurpose purpose;
  final int? camporeeId;

  /// 'local' | 'union' — v1.1: para camporees de unión el Campo Local del
  /// emisor sigue cobrando; solo cambia el endpoint de emisión.
  final String camporeeType;

  const IssuePaymentOrderView({
    super.key,
    required this.purpose,
    this.camporeeId,
    this.camporeeType = 'local',
  }) : assert(
          purpose != PaymentOrderPurpose.camporee || camporeeId != null,
          'camporeeId es requerido para órdenes de camporee',
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(paymentOrdersContextProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: purpose == PaymentOrderPurpose.insurance
              ? 'payment_orders.issue.title_insurance'.tr()
              : 'payment_orders.issue.title_camporee'.tr(),
          backgroundColor: c.surface,
          foregroundColor: c.text,
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: contextAsync.when(
              loading: () => const Center(child: SacLoading()),
              error: (_, __) => _UnavailableState(c: c),
              data: (ordersContext) {
                if (ordersContext == null || !ordersContext.enabled) {
                  return _UnavailableState(c: c);
                }
                if (purpose == PaymentOrderPurpose.insurance &&
                    ordersContext.insuranceCycles.isEmpty) {
                  return _NoCycleState(c: c);
                }
                return _IssueOrderForm(
                  purpose: purpose,
                  camporeeId: camporeeId,
                  camporeeType: camporeeType,
                  cycle: purpose == PaymentOrderPurpose.insurance
                      ? ordersContext.insuranceCycles.first
                      : null,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _IssueOrderForm extends ConsumerWidget {
  final PaymentOrderPurpose purpose;
  final int? camporeeId;
  final String camporeeType;
  final InsuranceCycleOption? cycle;

  const _IssueOrderForm({
    required this.purpose,
    required this.camporeeId,
    required this.camporeeType,
    required this.cycle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issueState = ref.watch(issueOrderNotifierProvider);
    final membersAsync = ref.watch(membersInsuranceProvider);
    final isCamporee = purpose == PaymentOrderPurpose.camporee;
    final registeredIdsAsync = isCamporee
        ? ref.watch(camporeeRegisteredUserIdsProvider(camporeeId!))
        : const AsyncValue<Set<String>>.data({});
    final ordersKey = (camporeeId: camporeeId ?? 0, camporeeType: camporeeType);
    final heldAsync = isCamporee
        ? ref.watch(camporeeHeldBeneficiariesProvider(ordersKey))
        : const AsyncValue<Map<String, String>>.data({});
    final c = context.sac;

    // Camporee orders charge the camporee's registration cost per member.
    final camporeeCost = isCamporee
        ? ref.watch(camporeeDetailProvider(camporeeId!)).value?.registrationCost
        : null;
    final unitCost = cycle?.unitCostCentavos ??
        (camporeeCost != null && camporeeCost > 0
            ? (camporeeCost * 100).round()
            : null);
    final selectedCount = issueState.selectedUserIds.length;
    final totalCentavos = unitCost != null ? unitCost * selectedCount : null;

    if (membersAsync.isLoading ||
        registeredIdsAsync.isLoading ||
        heldAsync.isLoading) {
      return const Center(child: SacLoading());
    }
    if (membersAsync.hasError) {
      return _IssueLoadError(
        message: userErrorMessage(membersAsync.error),
        onRetry: () => ref.invalidate(membersInsuranceProvider),
      );
    }
    if (registeredIdsAsync.hasError) {
      return _IssueLoadError(
        message: userErrorMessage(registeredIdsAsync.error),
        onRetry: () =>
            ref.invalidate(camporeeRegisteredUserIdsProvider(camporeeId!)),
      );
    }
    if (heldAsync.hasError) {
      return _IssueLoadError(
        message: userErrorMessage(heldAsync.error),
        onRetry: () =>
            ref.invalidate(camporeeHeldBeneficiariesProvider(ordersKey)),
      );
    }

    final members = membersAsync.value ?? const <MemberInsurance>[];
    final registeredIds = registeredIdsAsync.value ?? const <String>{};
    final held = heldAsync.value ?? const <String, String>{};
    final candidates = members
        .where(
          (member) => isEligiblePaymentOrderBeneficiary(
            purpose: purpose,
            member: member,
            registeredCamporeeUserIds: registeredIds,
          ),
        )
        .toList()
      ..sort((a, b) => a.memberName.compareTo(b.memberName));
    // Members already in an open order can't go in a second one.
    final eligible =
        candidates.where((m) => !held.containsKey(m.memberId)).toList();
    final heldMembers =
        candidates.where((m) => held.containsKey(m.memberId)).toList();

    final notifier = ref.read(issueOrderNotifierProvider.notifier);
    final allSelected = eligible.isNotEmpty &&
        eligible.every((m) => issueState.selectedUserIds.contains(m.memberId));
    final title = 'payment_orders.issue.select_members'.tr().toUpperCase();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: SacTopBar.paddingBelowBar(
              context,
              const EdgeInsets.fromLTRB(20, 16, 20, 32),
            ),
            children: [
              if (cycle != null) ...[
                _CycleSummaryGroup(cycle: cycle!),
                const SizedBox(height: 24),
              ],
              SacSettingsGroup(
                key: const Key('issue-order-members'),
                title: eligible.isEmpty
                    ? title
                    : '$title · ${issueState.selectedUserIds.length}/${eligible.length}',
                children: eligible.isEmpty
                    ? [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedUserGroup,
                                size: 20,
                                color: c.textTertiary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'payment_orders.issue.no_eligible'.tr(),
                                  style: TextStyle(
                                    fontSize: SacFontSize.bodyMedium,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                    : [
                        SacSettingsTile(
                          key: const Key('issue-order-select-all'),
                          icon: allSelected
                              ? HugeIcons.strokeRoundedCancelSquare
                              : HugeIcons.strokeRoundedCheckList,
                          title: allSelected
                              ? 'payment_orders.issue.deselect_all'.tr()
                              : 'payment_orders.issue.select_all'.tr(),
                          trailing: const SizedBox.shrink(),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            allSelected
                                ? notifier.clearSelection()
                                : notifier.selectAll(
                                    eligible.map((m) => m.memberId),
                                  );
                          },
                        ),
                        for (final member in eligible) ...[
                          const SacSettingsDivider(),
                          _EligibleMemberTile(
                            member: member,
                            // Camporee lists insured members only: the
                            // badge would repeat it on every row.
                            showInsurance:
                                purpose == PaymentOrderPurpose.insurance,
                            selected: issueState.selectedUserIds
                                .contains(member.memberId),
                            onTap: () => notifier.toggle(member.memberId),
                          ),
                        ],
                      ],
              ),
              SacSettingsFooter(
                purpose == PaymentOrderPurpose.insurance
                    ? 'payment_orders.issue.eligible_hint_insurance'.tr()
                    : 'payment_orders.issue.eligible_hint_camporee'.tr(),
              ),
              if (heldMembers.isNotEmpty) ...[
                const SizedBox(height: 24),
                SacSettingsGroup(
                  key: const Key('issue-order-held-members'),
                  title: 'payment_orders.issue.held_title'.tr().toUpperCase(),
                  children: [
                    for (var i = 0; i < heldMembers.length; i++) ...[
                      if (i > 0) const SacSettingsDivider(),
                      _HeldMemberTile(
                        member: heldMembers[i],
                        folio: held[heldMembers[i].memberId]!,
                      ),
                    ],
                  ],
                ),
                SacSettingsFooter('payment_orders.issue.held_hint'.tr()),
              ],
            ],
          ),
        ),
        SacPinnedActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (issueState.errorMessage != null) ...[
                Container(
                  key: const Key('issue-order-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Text(
                    issueState.errorMessage!,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: c.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (totalCentavos != null && selectedCount > 0) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'payment_orders.issue.total_label'.tr(
                          namedArgs: {'count': selectedCount.toString()},
                        ),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      SacMoney.fromCentavos(totalCentavos),
                      style: TextStyle(
                        fontSize: SacFontSize.titleMedium,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              SacButton.primary(
                text: 'payment_orders.issue.submit'.tr(
                  namedArgs: {'count': selectedCount.toString()},
                ),
                icon: HugeIcons.strokeRoundedInvoice01,
                isLoading: issueState.isSubmitting,
                isEnabled: selectedCount > 0,
                onPressed: selectedCount == 0 || issueState.isSubmitting
                    ? null
                    : () => _submit(context, ref, totalCentavos),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    int? totalCentavos,
  ) async {
    final notifier = ref.read(issueOrderNotifierProvider.notifier);
    final count = ref.read(issueOrderNotifierProvider).selectedUserIds.length;
    final confirmed = await SacDialog.show(
      context,
      title: 'payment_orders.issue.confirm_title'.tr(),
      content: 'payment_orders.issue.confirm_body'.plural(count),
      highlight:
          totalCentavos != null ? SacMoney.fromCentavos(totalCentavos) : null,
      confirmLabel: 'payment_orders.issue.submit'.tr(),
      cancelLabel: 'common.cancel'.tr(),
    );
    if (confirmed != true || !context.mounted) return;

    final order = purpose == PaymentOrderPurpose.insurance
        ? await notifier.submitInsurance(cycleConfigId: cycle!.cycleConfigId)
        : await notifier.submitCamporee(
            camporeeId: camporeeId!,
            camporeeType: camporeeType,
          );

    if (order != null && context.mounted) {
      SacSnackBar.show(
          context,
          'payment_orders.issue.success'.tr(
            namedArgs: {'folio': order.folioReference},
          ),
          isSuccess: true);
      // This screen can sit on a plain Navigator route (opened from the
      // camporee). Pop it first and push the order through the router, so
      // back from the order returns to the camporee instead of Home.
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(RouteNames.paymentOrderDetailPath(order.orderId));
    }
  }
}

/// The insurance being bought: product, unit cost and deadline.
class _CycleSummaryGroup extends StatelessWidget {
  final InsuranceCycleOption cycle;

  const _CycleSummaryGroup({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd(context.locale.toString());
    final deadline = cycle.purchaseDeadline;

    return SacSettingsGroup(
      title: cycle.productName.toUpperCase(),
      children: [
        SacSettingsValueTile(
          icon: HugeIcons.strokeRoundedTicket01,
          label: 'payment_orders.detail.unit_cost'.tr(),
          value: SacMoney.fromCentavos(cycle.unitCostCentavos),
        ),
        if (deadline != null) ...[
          const SacSettingsDivider(),
          SacSettingsValueTile(
            icon: HugeIcons.strokeRoundedCalendar03,
            label: 'payment_orders.issue.deadline_short'.tr(),
            value: dateFormat.format(deadline.toLocal()),
          ),
        ],
      ],
    );
  }
}

/// One eligible member: a check circle on the left (iOS multi-select),
/// photo or initials, name and class, and the insurance status.
class _EligibleMemberTile extends StatelessWidget {
  final MemberInsurance member;
  final bool selected;
  final bool showInsurance;
  final VoidCallback onTap;

  const _EligibleMemberTile({
    required this.member,
    required this.selected,
    required this.showInsurance,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.press;

    return Semantics(
      selected: selected,
      child: SacInkWell(
        key: ValueKey('issue-order-member-${member.memberId}'),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: duration,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? accent.color : Colors.transparent,
                    border: Border.all(
                      color: selected ? accent.color : c.border,
                      width: 1.5,
                    ),
                  ),
                  child: selected
                      ? Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedTick02,
                            size: 14,
                            color: accent.onColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                SacMemberAvatar(
                  name: member.memberName,
                  imageUrl: member.memberPhotoUrl,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.memberName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      if (member.memberClass?.trim().isNotEmpty == true)
                        Text(
                          member.memberClass!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            color: c.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (showInsurance) ...[
                  const SizedBox(width: 8),
                  InsuranceStatusBadge(status: member.status, compact: true),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A member already held by an open order: shown greyed out with its folio,
/// so the director knows why it can't be selected.
class _HeldMemberTile extends StatelessWidget {
  final MemberInsurance member;
  final String folio;

  const _HeldMemberTile({required this.member, required this.folio});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return ConstrainedBox(
      key: ValueKey('issue-order-held-${member.memberId}'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Opacity(
              opacity: 0.6,
              child: SacMemberAvatar(
                name: member.memberName,
                imageUrl: member.memberPhotoUrl,
                size: 36,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: c.textSecondary,
                    ),
                  ),
                  Text(
                    'payment_orders.issue.held_in'
                        .tr(namedArgs: {'folio': folio}),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.bodySmall,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IssueLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _IssueLoadError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SacErrorState(
      title: 'common.error_state.title'.tr(),
      message: message,
      onRetry: onRetry,
    );
  }
}

class _UnavailableState extends StatelessWidget {
  final SacColors c;

  const _UnavailableState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedInvoice01,
              size: 46,
              color: c.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              'payment_orders.issue.unavailable'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: SacFontSize.bodyMedium, color: c.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCycleState extends StatelessWidget {
  final SacColors c;

  const _NoCycleState({required this.c});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Text(
          'payment_orders.issue.no_cycle'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: SacFontSize.bodyMedium, color: c.textSecondary),
        ),
      ),
    );
  }
}
