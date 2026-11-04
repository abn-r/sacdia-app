import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/insurance/domain/entities/member_insurance.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/widgets/insurance_status_badge.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/payment_orders/domain/entities/payment_order.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/views/issue_payment_order_view.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../domain/utils/camporee_registration_payment_flow.dart';
import '../providers/camporees_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/errors/user_error_message.dart';

/// Vista para seleccionar e inscribir miembros del club activo en un camporee.
///
/// El usuario no captura UUIDs ni tipo de camporee: la lista sale de la sección
/// activa y el backend infiere el tipo desde el endpoint de camporee local/unión.
class CamporeeRegisterMemberView extends ConsumerStatefulWidget {
  final int camporeeId;

  const CamporeeRegisterMemberView({
    super.key,
    required this.camporeeId,
  });

  @override
  ConsumerState<CamporeeRegisterMemberView> createState() =>
      _CamporeeRegisterMemberViewState();
}

class _CamporeeRegisterMemberViewState
    extends ConsumerState<CamporeeRegisterMemberView> {
  Set<String> _selectedUserIds = <String>{};

  @override
  Widget build(BuildContext context) {
    final sectionRegistrationAsync =
        ref.watch(camporeeSectionRegistrationProvider(widget.camporeeId));
    final authAsync = ref.watch(authNotifierProvider);
    final ordersContextAsync = ref.watch(paymentOrdersContextProvider);
    final c = context.sac;
    final paymentFlow = camporeeRegistrationPaymentFlow(
      isLoading: ordersContextAsync.isLoading,
      hasError: ordersContextAsync.hasError,
      enabled: ordersContextAsync.value?.enabled == true,
    );

    if (paymentFlow == CamporeeRegistrationPaymentFlow.paymentOrder) {
      return IssuePaymentOrderView(
        purpose: PaymentOrderPurpose.camporee,
        camporeeId: widget.camporeeId,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
          title: 'camporees.register_member.title'.tr(),
          backgroundColor: c.surface,
          foregroundColor: c.text,
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            top: false,
            child: switch (paymentFlow) {
              CamporeeRegistrationPaymentFlow.loading =>
                const _PaymentOrdersContextLoading(),
              CamporeeRegistrationPaymentFlow.unavailable => SacErrorState(
                  title: 'payment_orders.camporee_redirect.context_error'.tr(),
                  message: 'payment_orders.camporee_redirect.context_error_hint'
                      .tr(),
                  padding: SacTopBar.paddingBelowBar(
                    context,
                    const EdgeInsets.all(32),
                  ),
                  onRetry: () => ref.invalidate(paymentOrdersContextProvider),
                ),
              // El caso real regresa IssuePaymentOrderView antes del Scaffold.
              CamporeeRegistrationPaymentFlow.paymentOrder =>
                const SizedBox.shrink(),
              CamporeeRegistrationPaymentFlow.legacy =>
                CamporeeParticipantRegistrationGate(
                  registrationAsync: sectionRegistrationAsync,
                  authAsync: authAsync,
                  onRetryRegistration: () => ref.invalidate(
                    camporeeSectionRegistrationProvider(widget.camporeeId),
                  ),
                  onRetryAuth: () => ref.invalidate(authNotifierProvider),
                  child: _EligibleRegistrationForm(
                    camporeeId: widget.camporeeId,
                    selectedUserIds: _selectedUserIds,
                    onRemove: (userId) {
                      setState(() => _selectedUserIds.remove(userId));
                    },
                    onOpenPicker: () => _openMemberPicker(context),
                    onSubmit: (ids) => _submit(context, ids),
                  ),
                ),
            },
          ),
        ),
      ),
    );
  }

  Future<void> _openMemberPicker(BuildContext context) async {
    final selected = await showSacSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberPickerSheet(
        camporeeId: widget.camporeeId,
        initialSelectedIds: _selectedUserIds,
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedUserIds = selected);
    }
  }

  Future<void> _submit(
    BuildContext context,
    Map<String, int> insuranceIdsByUserId,
  ) async {
    if (insuranceIdsByUserId.isEmpty) {
      SacSnackBar.show(
        context,
        'camporees.register_member.already_selected'.tr(),
      );
      return;
    }

    final notifier = ref.read(
      camporeeRegistrationNotifierProvider(widget.camporeeId).notifier,
    );
    notifier.reset();

    final result = await notifier.registerMany(
      insuranceIdsByUserId: insuranceIdsByUserId,
    );

    if (!context.mounted) return;

    if (result.isSuccess) {
      SacSnackBar.show(
        context,
        'camporees.register_member.success_many'.tr(
          namedArgs: {'count': result.successCount.toString()},
        ),
        isSuccess: true,
      );
      Navigator.pop(context);
      return;
    }

    if (result.hasAnySuccess) {
      setState(() => _selectedUserIds.clear());
      SacSnackBar.show(
        context,
        'camporees.register_member.partial_success'.tr(
          namedArgs: {
            'success': result.successCount.toString(),
            'failed': result.failureCount.toString(),
          },
        ),
      );
    }
  }
}

class _EligibleRegistrationForm extends ConsumerWidget {
  final int camporeeId;
  final Set<String> selectedUserIds;
  final ValueChanged<String> onRemove;
  final VoidCallback onOpenPicker;
  final ValueChanged<Map<String, int>> onSubmit;

  const _EligibleRegistrationForm({
    required this.camporeeId,
    required this.selectedUserIds,
    required this.onRemove,
    required this.onOpenPicker,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final registrationState =
        ref.watch(camporeeRegistrationNotifierProvider(camporeeId));
    final membersAsync = ref.watch(membersInsuranceProvider);
    final registeredIdsAsync =
        ref.watch(camporeeRegisteredUserIdsProvider(camporeeId));
    final registeredIds = registeredIdsAsync.value ?? const <String>{};
    final selectedMembers = _selectedMembers(membersAsync.value);
    final insuranceIdsByUserId = _eligibleInsuranceIds(
      selectedMembers,
      registeredIds,
    );
    final pendingSelectedCount = selectedMembers
        .where((member) => !registeredIds.contains(member.memberId))
        .length;
    final hasSelectedWithoutEligibleInsurance =
        pendingSelectedCount > insuranceIdsByUserId.length;

    return SingleChildScrollView(
      padding: SacTopBar.paddingBelowBar(context, const EdgeInsets.all(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _InfoBanner(),
          const SizedBox(height: 22),
          if (registrationState.errorMessage != null) ...[
            _ErrorBanner(message: registrationState.errorMessage!),
            const SizedBox(height: 16),
          ],
          if (hasSelectedWithoutEligibleInsurance) ...[
            const SizedBox(height: 12),
            _ErrorBanner(
              message: 'camporees.register_member.insurance_error_body'.tr(),
            ),
          ],
          _SelectedMembersCard(
            selectedIds: selectedUserIds,
            selectedMembers: selectedMembers,
            onRemove: onRemove,
          ),
          const SizedBox(height: 14),
          SacButton.outline(
            text: selectedUserIds.isEmpty
                ? 'camporees.register_member.select_members_button'.tr()
                : 'camporees.register_member.modify_selection_button'.tr(),
            icon: HugeIcons.strokeRoundedUserGroup,
            onPressed: onOpenPicker,
          ),
          if (registeredIdsAsync.hasValue && registeredIds.isNotEmpty) ...[
            const SizedBox(height: 10),
            _AlreadyRegisteredHint(count: registeredIds.length),
          ],
          const SizedBox(height: 28),
          SacButton.primary(
            text: 'camporees.register_member.register_button_count'.tr(
              namedArgs: {'count': insuranceIdsByUserId.length.toString()},
            ),
            icon: HugeIcons.strokeRoundedUserAdd01,
            isLoading: registrationState.isLoading,
            isEnabled: insuranceIdsByUserId.isNotEmpty &&
                !hasSelectedWithoutEligibleInsurance,
            onPressed: registrationState.isLoading ||
                    insuranceIdsByUserId.isEmpty ||
                    hasSelectedWithoutEligibleInsurance
                ? null
                : () => onSubmit(insuranceIdsByUserId),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  List<MemberInsurance> _selectedMembers(List<MemberInsurance>? members) {
    if (members == null || selectedUserIds.isEmpty) return const [];
    final byId = {for (final member in members) member.memberId: member};
    return selectedUserIds
        .map((userId) => byId[userId])
        .whereType<MemberInsurance>()
        .toList();
  }

  Map<String, int> _eligibleInsuranceIds(
    List<MemberInsurance> members,
    Set<String> registeredIds,
  ) {
    return {
      for (final member in members)
        if (!registeredIds.contains(member.memberId) &&
            member.insuranceId != null &&
            member.status == InsuranceStatus.asegurado &&
            (member.insuranceType == InsuranceType.camporee ||
                member.insuranceType == InsuranceType.generalActivities))
          member.memberId: member.insuranceId!,
    };
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.warningContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: c.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 19,
            color: c.onWarningContainer,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'camporees.register_member.info_banner'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.onWarningContainer,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: c.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          color: c.onErrorContainer,
        ),
      ),
    );
  }
}

class _AlreadyRegisteredHint extends StatelessWidget {
  final int count;

  const _AlreadyRegisteredHint({required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
          size: 15,
          color: context.sac.onSuccessContainer,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'camporees.register_member.already_registered_hint'.tr(
              namedArgs: {'count': count.toString()},
            ),
            style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: context.sac.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _SelectedMembersCard extends StatelessWidget {
  final Set<String> selectedIds;
  final List<MemberInsurance> selectedMembers;
  final ValueChanged<String> onRemove;

  const _SelectedMembersCard({
    required this.selectedIds,
    required this.selectedMembers,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border),
      ),
      child: selectedIds.isEmpty
          ? SacEmptyState.inline(
              icon: HugeIcons.strokeRoundedUserGroup,
              title: 'camporees.register_member.selected_empty_title'.tr(),
              body: 'camporees.register_member.selected_empty_subtitle'.tr(),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserMultiple02,
                      size: 18,
                      color: SacAccent.of(context).color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'camporees.register_member.selection_title'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.titleSmall,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                      ),
                    ),
                    Text(
                      'camporees.register_member.selection_count'.tr(
                        namedArgs: {'count': selectedIds.length.toString()},
                      ),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        fontWeight: FontWeight.w700,
                        color: SacAccent.of(context).color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selectedMembers.isEmpty)
                  Text(
                    'camporees.register_member.selection_loading'.tr(
                      namedArgs: {'count': selectedIds.length.toString()},
                    ),
                    style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary),
                  )
                else ...[
                  ...selectedMembers.take(5).map(
                        (member) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _SelectedMemberTile(
                            member: member,
                            onRemove: () => onRemove(member.memberId),
                          ),
                        ),
                      ),
                  if (selectedIds.length > 5)
                    Text(
                      'camporees.register_member.selected_more'.tr(
                        namedArgs: {
                          'count': (selectedIds.length - 5).toString(),
                        },
                      ),
                      style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textSecondary),
                    ),
                ],
              ],
            ),
    );
  }
}

class _SelectedMemberTile extends StatelessWidget {
  final MemberInsurance member;
  final VoidCallback onRemove;

  const _SelectedMemberTile({required this.member, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      children: [
        _MemberAvatar(
          imageUrl: member.memberPhotoUrl,
          initials: _initials(member.memberName),
          size: 36,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                member.memberName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              Text(
                member.memberClass ?? 'camporees.register_member.no_class'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: SacFontSize.labelSmall, color: c.textSecondary),
              ),
            ],
          ),
        ),
        SacPressable(
          listenOnly: true,
          child: IconButton(
            enableFeedback: false,
            onPressed: onRemove,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 17,
              color: c.textTertiary,
            ),
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
          ),
        ),
      ],
    );
  }
}

class _MemberPickerSheet extends ConsumerStatefulWidget {
  final int camporeeId;
  final Set<String> initialSelectedIds;

  const _MemberPickerSheet({
    required this.camporeeId,
    required this.initialSelectedIds,
  });

  @override
  ConsumerState<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends ConsumerState<_MemberPickerSheet> {
  late Set<String> _selectedIds;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.initialSelectedIds};
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersInsuranceProvider);
    final registeredIdsAsync =
        ref.watch(camporeeRegisteredUserIdsProvider(widget.camporeeId));
    final c = context.sac;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusXL)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    children: [
                      Text(
                        'camporees.register_member.picker_title'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.headlineMedium,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'camporees.register_member.picker_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            color: c.textSecondary),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _searchController,
                        onChanged: (value) => setState(() => _query = value),
                        decoration: InputDecoration(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedSearch01,
                              size: 18,
                              color: c.textTertiary,
                            ),
                          ),
                          hintText:
                              'camporees.register_member.search_hint'.tr(),
                          hintStyle: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              color: c.textTertiary),
                          filled: true,
                          fillColor: c.surfaceVariant,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMD),
                            borderSide: BorderSide(
                              color: SacAccent.of(context).color,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _buildList(
                    context,
                    scrollController,
                    membersAsync,
                    registeredIdsAsync,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    border: Border(top: BorderSide(color: c.border)),
                  ),
                  child: SacButton.primary(
                    text: 'camporees.register_member.use_selection'.tr(
                      namedArgs: {'count': _selectedIds.length.toString()},
                    ),
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    onPressed: () => Navigator.pop(context, _selectedIds),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    ScrollController scrollController,
    AsyncValue<List<MemberInsurance>> membersAsync,
    AsyncValue<Set<String>> registeredIdsAsync,
  ) {
    if (membersAsync.isLoading || registeredIdsAsync.isLoading) {
      return const Center(child: SacLoading());
    }

    final error = membersAsync.whenOrNull(error: (error, _) => error) ??
        registeredIdsAsync.whenOrNull(error: (error, _) => error);
    if (error != null) {
      return SacErrorState(
        title: '',
        message: userErrorMessage(error),
        onRetry: () {
          ref.invalidate(membersInsuranceProvider);
          ref.invalidate(camporeeRegisteredUserIdsProvider(widget.camporeeId));
        },
      );
    }

    final registeredIds = registeredIdsAsync.value ?? const <String>{};
    final members = _filteredMembers(membersAsync.value ?? const []);

    if (members.isEmpty) {
      return SacEmptyState(
        icon: HugeIcons.strokeRoundedSearch01,
        title: _query.trim().isNotEmpty
            ? 'camporees.register_member.empty_search'.tr()
            : 'camporees.register_member.empty_members'.tr(),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: SacTopBar.paddingBelowBar(
          context, const EdgeInsets.fromLTRB(20, 4, 20, 18)),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final member = members[index];
        final alreadyRegistered = registeredIds.contains(member.memberId);
        final selected = _selectedIds.contains(member.memberId);

        return _MemberPickerTile(
          member: member,
          selected: selected,
          alreadyRegistered: alreadyRegistered,
          onTap: alreadyRegistered
              ? null
              : () {
                  setState(() {
                    if (selected) {
                      _selectedIds.remove(member.memberId);
                    } else {
                      _selectedIds.add(member.memberId);
                    }
                  });
                },
        );
      },
    );
  }

  List<MemberInsurance> _filteredMembers(List<MemberInsurance> members) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return members;

    return members
        .where((member) => member.memberName.toLowerCase().contains(query))
        .toList();
  }
}

class _MemberPickerTile extends StatelessWidget {
  final MemberInsurance member;
  final bool selected;
  final bool alreadyRegistered;
  final VoidCallback? onTap;

  const _MemberPickerTile({
    required this.member,
    required this.selected,
    required this.alreadyRegistered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Opacity(
      opacity: alreadyRegistered ? 0.72 : 1,
      child: Material(
        color: selected && !alreadyRegistered
            ? SacAccent.of(context).color.withValues(alpha: 0.07)
            : c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: SacInkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: selected && !alreadyRegistered
                    ? SacAccent.of(context).color.withValues(alpha: 0.45)
                    : c.border,
                width: selected && !alreadyRegistered ? 1.3 : 1,
              ),
            ),
            child: Row(
              children: [
                _MemberAvatar(
                  imageUrl: member.memberPhotoUrl,
                  initials: _initials(member.memberName),
                  size: 50,
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
                          fontSize: SacFontSize.titleSmall,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedSchool,
                            size: 13,
                            color: c.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              member.memberClass ??
                                  'camporees.register_member.no_class'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: SacFontSize.bodySmall,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          InsuranceStatusBadge(
                            status: member.status,
                            compact: true,
                          ),
                          if (alreadyRegistered)
                            _MiniBadge(
                              label:
                                  'camporees.register_member.already_enrolled'
                                      .tr(),
                              color: AppColors.secondary,
                            )
                          else if (selected)
                            _MiniBadge(
                              label: 'camporees.register_member.selected'.tr(),
                              color: SacAccent.of(context).color,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _SelectionIndicator(
                  selected: selected,
                  alreadyRegistered: alreadyRegistered,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool selected;
  final bool alreadyRegistered;

  const _SelectionIndicator({
    required this.selected,
    required this.alreadyRegistered,
  });

  @override
  Widget build(BuildContext context) {
    final active = selected || alreadyRegistered;
    final color =
        alreadyRegistered ? AppColors.secondary : SacAccent.of(context).color;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
        border: Border.all(
          color: active ? color : context.sac.border,
          width: 1.4,
        ),
      ),
      child: active
          ? Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                size: 18,
                color: color,
              ),
            )
          : null,
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textColor =
        color == AppColors.secondary ? c.onSuccessContainer : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String? imageUrl;
  final String initials;
  final double size;

  const _MemberAvatar({
    required this.imageUrl,
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: SacAccent.of(context).light, width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? SacProfileImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: (size * 2).round(),
                memCacheHeight: (size * 2).round(),
                placeholder: (_, __) => _AvatarInitials(initials: initials),
                errorWidget: (_, __, ___) =>
                    _AvatarInitials(initials: initials),
              )
            : _AvatarInitials(initials: initials),
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;

  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SacAccent.of(context).color.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          fontWeight: FontWeight.w800,
          color: SacAccent.of(context).dark,
        ),
      ),
    );
  }
}

class _PaymentOrdersContextLoading extends StatelessWidget {
  const _PaymentOrdersContextLoading();

  @override
  Widget build(BuildContext context) {
    final title = 'payment_orders.camporee_redirect.context_loading'.tr();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SacLoading(),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: context.sac.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first[0].toUpperCase();
  final last = parts.length > 1 ? parts.last[0].toUpperCase() : '';
  return '$first$last';
}
