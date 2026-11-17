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
import 'package:sacdia_app/features/insurance/domain/entities/insurance_overview.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/utils/insurance_formatting.dart';

import '../../../camporees/presentation/providers/camporees_providers.dart';
import '../../domain/utils/payment_order_eligibility.dart';
import '../providers/payment_orders_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Emisión de una orden de camporee: selecciona miembros con seguro vigente
/// del año (según el resumen de seguros) que aún no estén inscritos y emite la
/// orden de inscripción al camporee [camporeeId].
///
/// Las órdenes de seguro se emiten desde el módulo de Seguros
/// (`IssueInsuranceView`).
class IssuePaymentOrderView extends ConsumerWidget {
  final int camporeeId;

  /// 'local' | 'union' — v1.1: para camporees de unión el Campo Local del
  /// emisor sigue cobrando; solo cambia el endpoint de emisión.
  final String camporeeType;

  const IssuePaymentOrderView({
    super.key,
    required this.camporeeId,
    this.camporeeType = 'local',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contextAsync = ref.watch(paymentOrdersContextProvider);
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'payment_orders.issue.title_camporee'.tr(),
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
                return _IssueOrderForm(
                  camporeeId: camporeeId,
                  camporeeType: camporeeType,
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
  final int camporeeId;
  final String camporeeType;

  const _IssueOrderForm({
    required this.camporeeId,
    required this.camporeeType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final issueState = ref.watch(issueOrderNotifierProvider);
    final overviewAsync = ref.watch(insuranceOverviewProvider);
    final registeredIdsAsync =
        ref.watch(camporeeRegisteredUserIdsProvider(camporeeId));
    final ordersKey = (camporeeId: camporeeId, camporeeType: camporeeType);
    final heldAsync = ref.watch(camporeeHeldBeneficiariesProvider(ordersKey));
    final c = context.sac;

    // Camporee orders charge the camporee's registration cost per member.
    final camporeeCost =
        ref.watch(camporeeDetailProvider(camporeeId)).value?.registrationCost;
    final unitCost = camporeeCost != null && camporeeCost > 0
        ? (camporeeCost * 100).round()
        : null;
    final selectedCount = issueState.selectedUserIds.length;
    final totalCentavos = unitCost != null ? unitCost * selectedCount : null;

    if (overviewAsync.isLoading ||
        registeredIdsAsync.isLoading ||
        heldAsync.isLoading) {
      return const Center(child: SacLoading());
    }
    if (overviewAsync.hasError) {
      return _IssueLoadError(
        message: userErrorMessage(overviewAsync.error),
        onRetry: () => ref.invalidate(insuranceOverviewProvider),
      );
    }
    if (registeredIdsAsync.hasError) {
      return _IssueLoadError(
        message: userErrorMessage(registeredIdsAsync.error),
        onRetry: () =>
            ref.invalidate(camporeeRegisteredUserIdsProvider(camporeeId)),
      );
    }
    if (heldAsync.hasError) {
      return _IssueLoadError(
        message: userErrorMessage(heldAsync.error),
        onRetry: () =>
            ref.invalidate(camporeeHeldBeneficiariesProvider(ordersKey)),
      );
    }

    final people = overviewAsync.value?.people ?? const <InsurancePerson>[];
    final registeredIds = registeredIdsAsync.value ?? const <String>{};
    final held = heldAsync.value ?? const <String, String>{};
    final candidates = people
        .where(
          (person) => isEligibleCamporeeBeneficiary(
            person: person,
            registeredCamporeeUserIds: registeredIds,
          ),
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    // Members already in an open order can't go in a second one.
    final eligible =
        candidates.where((m) => !held.containsKey(m.userId)).toList();
    final heldMembers =
        candidates.where((m) => held.containsKey(m.userId)).toList();

    final notifier = ref.read(issueOrderNotifierProvider.notifier);
    final allSelected = eligible.isNotEmpty &&
        eligible.every((m) => issueState.selectedUserIds.contains(m.userId));
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
                                    eligible.map((m) => m.userId),
                                  );
                          },
                        ),
                        for (final member in eligible) ...[
                          const SacSettingsDivider(),
                          _EligibleMemberTile(
                            member: member,
                            selected: issueState.selectedUserIds
                                .contains(member.userId),
                            onTap: () => notifier.toggle(member.userId),
                          ),
                        ],
                      ],
              ),
              SacSettingsFooter(
                'payment_orders.issue.eligible_hint_camporee'.tr(),
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
                        folio: held[heldMembers[i].userId]!,
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

    final order = await notifier.submitCamporee(
      camporeeId: camporeeId,
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

/// One eligible member: a check circle on the left (iOS multi-select),
/// photo or initials, name and class, and the insurance status.
class _EligibleMemberTile extends StatelessWidget {
  final InsurancePerson member;
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
    final accent = SacAccent.of(context);
    final duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.press;

    return Semantics(
      selected: selected,
      child: SacInkWell(
        key: ValueKey('issue-order-member-${member.userId}'),
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
                  name: member.name,
                  imageUrl: member.picture,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.titleMedium,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      if (member.roleLabel?.trim().isNotEmpty == true)
                        Text(
                          insuranceRoleLine(member),
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
  final InsurancePerson member;
  final String folio;

  const _HeldMemberTile({required this.member, required this.folio});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return ConstrainedBox(
      key: ValueKey('issue-order-held-${member.userId}'),
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Opacity(
              opacity: 0.6,
              child: SacMemberAvatar(
                name: member.name,
                imageUrl: member.picture,
                size: 36,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
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
