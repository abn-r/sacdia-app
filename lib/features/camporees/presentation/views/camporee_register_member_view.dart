import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/insurance/domain/entities/member_insurance.dart';
import 'package:sacdia_app/features/insurance/presentation/providers/insurance_providers.dart';
import 'package:sacdia_app/features/insurance/presentation/widgets/insurance_status_badge.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/camporees/presentation/widgets/camporee_participant_access_gate.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/payment_orders/presentation/providers/payment_orders_providers.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../domain/utils/camporee_registration_payment_flow.dart';
import '../providers/camporees_providers.dart';

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
      enabled: ordersContextAsync.valueOrNull?.enabled == true,
    );

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('camporees.register_member.title'.tr()),
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
      ),
      body: SafeArea(
        child: switch (paymentFlow) {
          CamporeeRegistrationPaymentFlow.loading =>
            const _PaymentOrdersContextLoading(),
          CamporeeRegistrationPaymentFlow.unavailable =>
            _PaymentOrdersContextError(
              onRetry: () => ref.invalidate(paymentOrdersContextProvider),
            ),
          CamporeeRegistrationPaymentFlow.paymentOrder =>
            _PaymentOrderRedirectBody(camporeeId: widget.camporeeId),
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
      _showSnack(
        context,
        'camporees.register_member.already_selected'.tr(),
        AppColors.accent,
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
      _showSnack(
        context,
        'camporees.register_member.success_many'.tr(
          namedArgs: {'count': result.successCount.toString()},
        ),
        AppColors.secondary,
      );
      Navigator.pop(context);
      return;
    }

    if (result.hasAnySuccess) {
      setState(() => _selectedUserIds.clear());
      _showSnack(
        context,
        'camporees.register_member.partial_success'.tr(
          namedArgs: {
            'success': result.successCount.toString(),
            'failed': result.failureCount.toString(),
          },
        ),
        AppColors.accent,
      );
    }
  }

  void _showSnack(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
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
    final registeredIds = registeredIdsAsync.valueOrNull ?? const <String>{};
    final selectedMembers = _selectedMembers(membersAsync.valueOrNull);
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
      padding: const EdgeInsets.all(20),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedInformationCircle,
            size: 19,
            color: AppColors.accentDark,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'camporees.register_member.info_banner'.tr(),
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.accentDark,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: AppColors.error),
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
          color: AppColors.secondary,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'camporees.register_member.already_registered_hint'.tr(
              namedArgs: {'count': count.toString()},
            ),
            style: TextStyle(fontSize: 12, color: context.sac.textSecondary),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: selectedIds.isEmpty
          ? _EmptySelection(c: c)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserMultiple02,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'camporees.register_member.selection_title'.tr(),
                        style: TextStyle(
                          fontSize: 14,
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
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
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
                    style: TextStyle(fontSize: 12, color: c.textSecondary),
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
                      style: TextStyle(fontSize: 12, color: c.textSecondary),
                    ),
                ],
              ],
            ),
    );
  }
}

class _EmptySelection extends StatelessWidget {
  final SacColors c;

  const _EmptySelection({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              size: 23,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'camporees.register_member.selected_empty_title'.tr(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'camporees.register_member.selected_empty_subtitle'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, height: 1.4, color: c.textSecondary),
        ),
      ],
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
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              Text(
                member.memberClass ?? 'camporees.register_member.no_class'.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onRemove,
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCancel01,
            size: 17,
            color: c.textTertiary,
          ),
          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Column(
                    children: [
                      Text(
                        'camporees.register_member.picker_title'.tr(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'camporees.register_member.picker_subtitle'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: c.textSecondary),
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
                          hintStyle:
                              TextStyle(fontSize: 13, color: c.textTertiary),
                          filled: true,
                          fillColor: c.surfaceVariant,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: c.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: c.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
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
      return _PickerError(
        message: error.toString().replaceFirst('Exception: ', ''),
        onRetry: () {
          ref.invalidate(membersInsuranceProvider);
          ref.invalidate(camporeeRegisteredUserIdsProvider(widget.camporeeId));
        },
      );
    }

    final registeredIds = registeredIdsAsync.valueOrNull ?? const <String>{};
    final members = _filteredMembers(membersAsync.valueOrNull ?? const []);

    if (members.isEmpty) {
      return _PickerEmpty(hasQuery: _query.trim().isNotEmpty);
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
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
            ? AppColors.primary.withValues(alpha: 0.07)
            : c.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected && !alreadyRegistered
                    ? AppColors.primary.withValues(alpha: 0.45)
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
                          fontSize: 14.5,
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
                                fontSize: 12,
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
                              color: AppColors.primary,
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
    final color = alreadyRegistered ? AppColors.secondary : AppColors.primary;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
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
        border: Border.all(color: AppColors.primaryLight, width: 2),
      ),
      child: ClipOval(
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? CachedNetworkImage(
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
      color: AppColors.primary.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }
}

class _PickerError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PickerError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 42,
              color: AppColors.error,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: context.sac.textSecondary),
            ),
            const SizedBox(height: 14),
            SacButton.outline(
              text: 'common.retry'.tr(),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerEmpty extends StatelessWidget {
  final bool hasQuery;

  const _PickerEmpty({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasQuery
              ? 'camporees.register_member.empty_search'.tr()
              : 'camporees.register_member.empty_members'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: context.sac.textSecondary),
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
                  fontSize: 15,
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

class _PaymentOrdersContextError extends StatelessWidget {
  final VoidCallback onRetry;

  const _PaymentOrdersContextError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Semantics(
          container: true,
          liveRegion: true,
          label: 'payment_orders.camporee_redirect.context_error'.tr(),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'payment_orders.camporee_redirect.context_error'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'payment_orders.camporee_redirect.context_error_hint'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: c.textSecondary,
                        height: 1.45,
                      ),
                ),
                const SizedBox(height: 16),
                SacButton.outline(
                  text: 'common.retry'.tr(),
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: onRetry,
                  textColor: c.text,
                  borderColor: c.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cómo inscribir cuando el campo cobra con orden de pago: pasos + CTA
/// a la lista de miembros. No es un empty-state de factura.
class _PaymentOrderRedirectBody extends StatelessWidget {
  final int camporeeId;

  const _PaymentOrderRedirectBody({required this.camporeeId});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return ColoredBox(
      color: c.surfaceVariant,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          SacCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'payment_orders.camporee_redirect.title'.tr(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                const _EnrollHowToStep(index: 1, l10nKey: 'step_1'),
                const SizedBox(height: 14),
                const _EnrollHowToStep(index: 2, l10nKey: 'step_2'),
                const SizedBox(height: 14),
                const _EnrollHowToStep(index: 3, l10nKey: 'step_3'),
                const SizedBox(height: 14),
                const _EnrollHowToStep(index: 4, l10nKey: 'step_4'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SacButton.primary(
            key: const Key('camporee-register-choose-members'),
            text: 'payment_orders.camporee_redirect.issue_button'.tr(),
            icon: HugeIcons.strokeRoundedUserAdd01,
            onPressed: () => context.push(
              RouteNames.camporeeIssuePaymentOrderPath(camporeeId),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: SacButton.ghost(
              key: const Key('camporee-register-view-orders'),
              text: 'payment_orders.camporee_redirect.view_orders'.tr(),
              textColor: AppColors.primary,
              onPressed: () => context.push(
                '${RouteNames.paymentOrders}?purpose=CAMPOREE&camporee_id=$camporeeId',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EnrollHowToStep extends StatelessWidget {
  final int index;
  final String l10nKey;

  const _EnrollHowToStep({
    required this.index,
    required this.l10nKey,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$index',
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'payment_orders.camporee_redirect.$l10nKey'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c.text,
              height: 1.35,
            ),
          ),
        ),
      ],
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
