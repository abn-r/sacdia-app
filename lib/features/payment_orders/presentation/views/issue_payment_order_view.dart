import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/insurance/domain/entities/member_insurance.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/widgets/insurance_status_badge.dart';

import '../../domain/entities/payment_order.dart';
import '../providers/payment_orders_providers.dart';
import '../widgets/payment_order_widgets.dart';

/// Flujo de emisión de una orden de pago territorial.
///
/// - [PaymentOrderPurpose.insurance]: selecciona miembros SIN cobertura activa
///   del ciclo aplicable y emite la orden de seguro.
/// - [PaymentOrderPurpose.camporee]: selecciona miembros con seguro activo y
///   emite la orden de inscripción al camporee [camporeeId].
class IssuePaymentOrderView extends ConsumerWidget {
  final PaymentOrderPurpose purpose;
  final int? camporeeId;

  const IssuePaymentOrderView({
    super.key,
    required this.purpose,
    this.camporeeId,
  }) : assert(
          purpose != PaymentOrderPurpose.camporee || camporeeId != null,
          'camporeeId es requerido para órdenes de camporee',
        );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(paymentOrdersContextProvider);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text(
          purpose == PaymentOrderPurpose.insurance
              ? 'payment_orders.issue.title_insurance'.tr()
              : 'payment_orders.issue.title_camporee'.tr(),
        ),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: SafeArea(
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
              cycle: purpose == PaymentOrderPurpose.insurance
                  ? ordersContext.insuranceCycles.first
                  : null,
            );
          },
        ),
      ),
    );
  }
}

class _IssueOrderForm extends ConsumerWidget {
  final PaymentOrderPurpose purpose;
  final int? camporeeId;
  final InsuranceCycleOption? cycle;

  const _IssueOrderForm({
    required this.purpose,
    required this.camporeeId,
    required this.cycle,
  });

  bool _isEligible(MemberInsurance member) {
    if (purpose == PaymentOrderPurpose.insurance) {
      // Elegible para asegurar: aún no tiene cobertura activa.
      return member.status != InsuranceStatus.asegurado;
    }
    // Camporee: requiere seguro activo.
    return member.status == InsuranceStatus.asegurado;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issueState = ref.watch(issueOrderNotifierProvider);
    final membersAsync = ref.watch(membersInsuranceProvider);
    final c = context.sac;

    final unitCost = cycle?.unitCostCentavos;
    final selectedCount = issueState.selectedUserIds.length;
    final totalCentavos = unitCost != null ? unitCost * selectedCount : null;

    return membersAsync.when(
      loading: () => const Center(child: SacLoading()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                error.toString().replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.textSecondary),
              ),
              const SizedBox(height: 14),
              SacButton.outline(
                text: 'common.retry'.tr(),
                onPressed: () => ref.invalidate(membersInsuranceProvider),
              ),
            ],
          ),
        ),
      ),
      data: (members) {
        final eligible = members.where(_isEligible).toList()
          ..sort((a, b) => a.memberName.compareTo(b.memberName));

        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (cycle != null) ...[
                    _CycleSummaryCard(cycle: cycle!),
                    const SizedBox(height: 16),
                  ],
                  if (issueState.errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        issueState.errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'payment_orders.issue.select_members'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    purpose == PaymentOrderPurpose.insurance
                        ? 'payment_orders.issue.eligible_hint_insurance'.tr()
                        : 'payment_orders.issue.eligible_hint_camporee'.tr(),
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  if (eligible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        'payment_orders.issue.no_eligible'.tr(),
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 13, color: c.textSecondary),
                      ),
                    )
                  else
                    ...eligible.map(
                      (member) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EligibleMemberTile(
                          member: member,
                          selected: issueState.selectedUserIds
                              .contains(member.memberId),
                          onTap: () => ref
                              .read(issueOrderNotifierProvider.notifier)
                              .toggle(member.memberId),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: c.surface,
                border: Border(top: BorderSide(color: c.border)),
              ),
              child: Column(
                children: [
                  if (totalCentavos != null && selectedCount > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'payment_orders.issue.total_label'.tr(
                            namedArgs: {'count': selectedCount.toString()},
                          ),
                          style: TextStyle(
                            fontSize: 13,
                            color: c.textSecondary,
                          ),
                        ),
                        Text(
                          formatCentavos(totalCentavos),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: c.text,
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
                        : () => _submit(context, ref),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submit(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(issueOrderNotifierProvider.notifier);
    final order = purpose == PaymentOrderPurpose.insurance
        ? await notifier.submitInsurance(cycleConfigId: cycle!.cycleConfigId)
        : await notifier.submitCamporee(camporeeId: camporeeId!);

    if (order != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'payment_orders.issue.success'.tr(
              namedArgs: {'folio': order.folioReference},
            ),
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      context.pushReplacement(
        RouteNames.paymentOrderDetailPath(order.orderId),
      );
    }
  }
}

class _CycleSummaryCard extends StatelessWidget {
  final InsuranceCycleOption cycle;

  const _CycleSummaryCard({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat.yMMMd(context.locale.toString());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cycle.productName,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'payment_orders.issue.unit_cost_label'.tr(
              namedArgs: {'cost': formatCentavos(cycle.unitCostCentavos)},
            ),
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          if (cycle.purchaseDeadline != null)
            Text(
              'payment_orders.issue.deadline_label'.tr(
                namedArgs: {
                  'date': dateFormat.format(cycle.purchaseDeadline!.toLocal()),
                },
              ),
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _EligibleMemberTile extends StatelessWidget {
  final MemberInsurance member;
  final bool selected;
  final VoidCallback onTap;

  const _EligibleMemberTile({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.07) : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : c.border,
              width: selected ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.memberName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InsuranceStatusBadge(status: member.status, compact: true),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.primary : c.border,
                    width: 1.4,
                  ),
                ),
                child: selected
                    ? const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 17,
                          color: AppColors.primary,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
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
              style: TextStyle(fontSize: 13.5, color: c.textSecondary),
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
          style: TextStyle(fontSize: 13.5, color: c.textSecondary),
        ),
      ),
    );
  }
}
