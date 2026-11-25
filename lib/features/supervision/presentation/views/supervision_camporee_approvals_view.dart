import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/errors/forbidden.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/money_format.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/coordinator/presentation/widgets/approval_action_buttons.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_action_result.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_card_header.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';

/// Server limit of a rejection reason.
const int _kReasonMaxLength = 500;

/// Shortest reason worth keeping in the audit trail.
const int _kReasonMinLength = 5;

/// Late registrations and payments of one union camporee that wait for a
/// decision: clubs, members and payments, each with approve and reject.
class SupervisionCamporeeApprovalsView extends ConsumerStatefulWidget {
  const SupervisionCamporeeApprovalsView({super.key, required this.camporeeId});

  /// Path parameter; anything that is not a camporee id shows the error state.
  final String camporeeId;

  @override
  ConsumerState<SupervisionCamporeeApprovalsView> createState() =>
      _SupervisionCamporeeApprovalsViewState();
}

class _SupervisionCamporeeApprovalsViewState
    extends ConsumerState<SupervisionCamporeeApprovalsView> {
  /// Kind picked by hand; null follows the first kind with something waiting.
  SupervisionCamporeeApprovalKind? _picked;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final id = int.tryParse(widget.camporeeId);
    final title = 'supervision.union_camporees.approvals_title'.tr();

    if (id == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        appBar: SacTopBar(title: title, frosted: true),
        body: SacFrostedVeil(
          child: SupervisionScroll(
            onRefresh: () async {},
            fill: true,
            child: SacErrorState(
              title: 'supervision.union_camporees.approvals_error_title'.tr(),
              message: 'supervision.union_camporees.error_message'.tr(),
            ),
          ),
        ),
      );
    }

    final provider = supervisionCamporeePendingProvider(id);
    final async = ref.watch(provider);
    // A failed refresh keeps the last queue on screen.
    final pending = async.value;
    final camporeeName =
        ref.watch(supervisionUnionCamporeeProvider(id)).value?.name.trim();

    Future<void> refresh() async {
      ref.invalidate(provider);
      ref.invalidate(supervisionPendingCountsProvider);
      try {
        await ref.read(provider.future);
      } catch (_) {
        // The body renders the error.
      }
    }

    final Widget body;
    if (pending == null && async.hasError) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: isForbiddenFailure(async.error!)
            ? const ForbiddenView()
            : SacErrorState(
                title: 'supervision.union_camporees.approvals_error_title'.tr(),
                message: 'supervision.union_camporees.error_message'.tr(),
                onRetry: refresh,
              ),
      );
    } else if (pending == null) {
      body = SupervisionScroll(
        onRefresh: refresh,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
          child: SacSkeletonList(
            itemCount: 5,
            leading: false,
            scrollable: false,
          ),
        ),
      );
    } else if (pending.total == 0) {
      body = SupervisionScroll(
        onRefresh: refresh,
        fill: true,
        child: SacEmptyState(
          title: 'supervision.union_camporees.approvals_empty_title'.tr(),
          body: 'supervision.union_camporees.approvals_empty_body'.tr(),
        ),
      );
    } else {
      final kind = _picked ?? _firstWaiting(pending);
      body = _Queue(
        camporeeId: id,
        pending: pending,
        kind: kind,
        onKind: (value) => setState(() => _picked = value),
        onRefresh: refresh,
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: title,
        subtitle:
            camporeeName == null || camporeeName.isEmpty ? null : camporeeName,
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }
}

SupervisionCamporeeApprovalKind _firstWaiting(
  SupervisionCamporeePending pending,
) {
  if (pending.clubs.isNotEmpty) return SupervisionCamporeeApprovalKind.club;
  if (pending.members.isNotEmpty) return SupervisionCamporeeApprovalKind.member;
  return SupervisionCamporeeApprovalKind.payment;
}

String _orUnnamed(String value, String fallbackKey) =>
    value.trim().isEmpty ? fallbackKey.tr() : value;

String _paymentTypeLabel(SupervisionCamporeePaymentType type) => switch (type) {
      SupervisionCamporeePaymentType.inscription =>
        'supervision.union_camporees.payment_inscription',
      SupervisionCamporeePaymentType.materials =>
        'supervision.union_camporees.payment_materials',
      _ => 'supervision.union_camporees.payment_other',
    }
        .tr();

// ── The queue of one kind ───────────────────────────────────────────────────

class _Queue extends StatelessWidget {
  const _Queue({
    required this.camporeeId,
    required this.pending,
    required this.kind,
    required this.onKind,
    required this.onRefresh,
  });

  final int camporeeId;
  final SupervisionCamporeePending pending;
  final SupervisionCamporeeApprovalKind kind;
  final ValueChanged<SupervisionCamporeeApprovalKind> onKind;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      ...switch (kind) {
        SupervisionCamporeeApprovalKind.club => [
            for (final club in pending.clubs)
              _ItemCard(
                title: _orUnnamed(
                  club.clubName,
                  'supervision.union_camporees.unknown_club',
                ),
                when: club.createdAt,
                secondary: club.sectionName,
                detail: club.registeredByName == null
                    ? null
                    : 'supervision.union_camporees.registered_by'
                        .tr(args: [club.registeredByName!]),
                onTap: () => _showItem(
                  context,
                  _ItemSheet.club(camporeeId: camporeeId, club: club),
                ),
              ),
          ],
        SupervisionCamporeeApprovalKind.member => [
            for (final member in pending.members)
              _ItemCard(
                title: _orUnnamed(
                  member.fullName,
                  'supervision.union_camporees.unknown_member',
                ),
                when: member.createdAt,
                secondary: member.clubName,
                detail: (member.insuranceVerified
                        ? 'supervision.union_camporees.insurance_verified'
                        : 'supervision.union_camporees.insurance_unverified')
                    .tr(),
                // A missing insurance is what the reviewer must not miss.
                detailStrong: !member.insuranceVerified,
                onTap: () => _showItem(
                  context,
                  _ItemSheet.member(camporeeId: camporeeId, member: member),
                ),
              ),
          ],
        SupervisionCamporeeApprovalKind.payment => [
            for (final payment in pending.payments)
              _ItemCard(
                title: _orUnnamed(
                  payment.memberName,
                  'supervision.union_camporees.unknown_member',
                ),
                when: payment.createdAt,
                secondary: payment.clubName,
                detail: '${SacMoney.format(payment.amount)} · '
                    '${_paymentTypeLabel(payment.type)}',
                detailStrong: true,
                onTap: () => _showItem(
                  context,
                  _ItemSheet.payment(camporeeId: camporeeId, payment: payment),
                ),
              ),
          ],
      },
    ];

    return SafeArea(
      top: false,
      child: RefreshIndicator(
        color: SacAccent.of(context).color,
        edgeOffset: SacTopBar.frostedInset(context),
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: SacTopBar.paddingBelowBar(
                context,
                const EdgeInsets.only(top: 8),
              ),
              sliver: SliverToBoxAdapter(
                child: _KindChips(
                  pending: pending,
                  selected: kind,
                  onSelected: onKind,
                ),
              ),
            ),
            // Centered column on a tablet.
            SliverLayoutBuilder(
              builder: (context, constraints) {
                final side = (constraints.crossAxisExtent -
                        kSupervisionMaxContentWidth) /
                    2;
                return SliverPadding(
                  padding: EdgeInsets.symmetric(
                    horizontal: side > 0 ? side : 0,
                  ),
                  sliver: cards.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: SacEmptyState(
                            title:
                                'supervision.union_camporees.kind_empty_title'
                                    .tr(),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                          sliver: SliverList.separated(
                            itemCount: cards.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) => cards[index],
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _KindChips extends StatelessWidget {
  const _KindChips({
    required this.pending,
    required this.selected,
    required this.onSelected,
  });

  final SupervisionCamporeePending pending;
  final SupervisionCamporeeApprovalKind selected;
  final ValueChanged<SupervisionCamporeeApprovalKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final options = [
      (
        SupervisionCamporeeApprovalKind.club,
        'supervision.union_camporees.kind_clubs',
        pending.clubs.length,
      ),
      (
        SupervisionCamporeeApprovalKind.member,
        'supervision.union_camporees.kind_members',
        pending.members.length,
      ),
      (
        SupervisionCamporeeApprovalKind.payment,
        'supervision.union_camporees.kind_payments',
        pending.payments.length,
      ),
    ];
    return SizedBox(
      height: SacFilterChip.barHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: options.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (kind, labelKey, count) = options[index];
          return Center(
            child: SacFilterChip(
              label: count > 0
                  ? '${labelKey.tr()} · ${supervisionCount(context, count)}'
                  : labelKey.tr(),
              selected: kind == selected,
              onTap: () => onSelected(kind),
            ),
          );
        },
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.title,
    required this.when,
    required this.secondary,
    required this.detail,
    required this.onTap,
    this.detailStrong = false,
  });

  final String title;
  final DateTime? when;
  final String secondary;
  final String? detail;
  final bool detailStrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: SacCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SupervisionCardHeader(title: title, when: when),
              if (secondary.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  secondary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.3,
                    color: c.textSecondary,
                  ),
                ),
              ],
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.3,
                    color: detailStrong ? c.text : c.textSecondary,
                    fontWeight:
                        detailStrong ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── One item: what it is, and the decision ──────────────────────────────────

Future<void> _showItem(BuildContext context, _ItemSheet sheet) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => sheet,
  );
}

class _ItemSheet extends ConsumerStatefulWidget {
  const _ItemSheet.club({
    required this.camporeeId,
    required SupervisionCamporeePendingClub this.club,
  })  : member = null,
        payment = null;

  const _ItemSheet.member({
    required this.camporeeId,
    required SupervisionCamporeePendingMember this.member,
  })  : club = null,
        payment = null;

  const _ItemSheet.payment({
    required this.camporeeId,
    required SupervisionCamporeePendingPayment this.payment,
  })  : club = null,
        member = null;

  final int camporeeId;
  final SupervisionCamporeePendingClub? club;
  final SupervisionCamporeePendingMember? member;
  final SupervisionCamporeePendingPayment? payment;

  @override
  ConsumerState<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends ConsumerState<_ItemSheet> {
  bool _busy = false;
  String? _error;

  bool get _isPayment => widget.payment != null;

  String get _name {
    final raw = widget.club?.clubName ??
        widget.member?.fullName ??
        widget.payment?.memberName ??
        '';
    return _orUnnamed(
      raw,
      widget.club != null
          ? 'supervision.union_camporees.unknown_club'
          : 'supervision.union_camporees.unknown_member',
    );
  }

  Future<SupervisionActionResult> _send({
    required bool approve,
    String? reason,
  }) {
    final actions = ref.read(supervisionCamporeeApprovalActionsProvider);
    final id = widget.camporeeId;
    if (widget.club != null) {
      return actions.decideClub(
        id,
        widget.club!.id,
        approve: approve,
        reason: reason,
      );
    }
    if (widget.member != null) {
      return actions.decideMember(
        id,
        widget.member!.id,
        approve: approve,
        reason: reason,
      );
    }
    return actions.decidePayment(
      id,
      widget.payment!.id,
      approve: approve,
      reason: reason,
    );
  }

  Future<void> _decide({required bool approve}) async {
    final what = _isPayment ? 'payment' : 'registration';
    String? reason;
    if (approve) {
      final confirmed = await SacDialog.show(
        context,
        title: 'supervision.union_camporees.approve_${what}_title'
            .tr(args: [_name]),
        content: 'supervision.union_camporees.approve_${what}_message'.tr(),
        confirmLabel: 'coordinator.actions.approve'.tr(),
        cancelLabel: 'common.cancel'.tr(),
        confirmIsSuccess: true,
      );
      if (confirmed != true || !mounted) return;
    } else {
      reason = await showSupervisionDecisionSheet(
        context: context,
        title: 'supervision.union_camporees.reject_${what}_title'
            .tr(args: [_name]),
        message: 'supervision.union_camporees.reject_message'.tr(),
        fieldLabel: 'supervision.union_camporees.reason_label'.tr(),
        fieldHint: 'supervision.union_camporees.reason_hint'.tr(),
        confirmLabel: 'coordinator.actions.reject'.tr(),
        minLength: _kReasonMinLength,
        maxLength: _kReasonMaxLength,
      );
      if (reason == null || !mounted) return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _send(approve: approve, reason: reason);
    if (!mounted) return;
    if (result.ok) {
      SacSnackBar.show(
        context,
        'supervision.union_camporees.${approve ? 'approved' : 'rejected'}'
                '_${what}_toast'
            .tr(),
        isSuccess: true,
      );
      Navigator.of(context).pop();
      return;
    }
    final code = result.errorCode ?? '';
    // Someone else already decided it: nothing left to do in this sheet.
    if (code.endsWith('_PENDING_NOT_FOUND')) {
      SacSnackBar.show(
        context,
        'supervision.union_camporees.error_already_decided'.tr(),
        isError: true,
      );
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _error = switch (code) {
        'CAMPOREE_CLUB_REGISTRATION_CLOSED' =>
          'supervision.union_camporees.error_registration_closed'.tr(),
        _ when result.isForbidden =>
          'supervision.union_camporees.error_forbidden'.tr(),
        _ => supervisionErrorMessage(result.errorMessage),
      };
    });
  }

  void _openVoucher(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? '';
    if (path.endsWith('.pdf')) {
      SacPdfViewer.show(
        context,
        pdfSource: url,
        title: 'supervision.union_camporees.voucher'.tr(),
      );
      return;
    }
    // No share and no disk cache: a voucher is someone's payment proof.
    Navigator.of(context).push(
      SacFadeThroughRoute(
        fullscreenDialog: true,
        builder: (_) => SacImageViewer(
          imageUrl: url,
          title: 'supervision.union_camporees.voucher'.tr(),
          allowShare: false,
          cacheNetwork: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canDecide =
        hasCapability(user, 'union_camporees.approve_registrations');
    final voucher = widget.payment?.voucherUrl;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: _name,
            subtitle: (widget.club != null
                    ? 'supervision.union_camporees.sheet_club'
                    : widget.member != null
                        ? 'supervision.union_camporees.sheet_member'
                        : 'supervision.union_camporees.sheet_payment')
                .tr(),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ItemFacts(
                    club: widget.club,
                    member: widget.member,
                    payment: widget.payment,
                  ),
                  if (voucher != null && voucher.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Material(
                        color: c.surface,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMD),
                          side: BorderSide(color: c.border),
                        ),
                        child: SacListRow(
                          leading: const SacListRowIcon(
                            HugeIcons.strokeRoundedAttachment01,
                          ),
                          title:
                              'supervision.union_camporees.view_voucher'.tr(),
                          onTap: () => _openVoucher(voucher),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    height: 1.35,
                    color: c.error,
                  ),
                ),
              ),
            ),
          if (canDecide)
            ApprovalActionBar(
              isLoading: _busy,
              onApprove: () => _decide(approve: true),
              onReject: () => _decide(approve: false),
            )
          else
            const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    );
  }
}

class _ItemFacts extends StatelessWidget {
  const _ItemFacts({
    required this.club,
    required this.member,
    required this.payment,
  });

  final SupervisionCamporeePendingClub? club;
  final SupervisionCamporeePendingMember? member;
  final SupervisionCamporeePendingPayment? payment;

  @override
  Widget build(BuildContext context) {
    SacValueRow row(String key, String value) => SacValueRow(
          label: 'supervision.union_camporees.$key'.tr(),
          value: value,
        );
    SacValueRow? optional(String key, String? value) =>
        value == null || value.trim().isEmpty ? null : row(key, value);
    String? date(DateTime? when) =>
        when == null ? null : supervisionShortDate(context, when.toLocal());

    final rows = <SacValueRow?>[
      if (club != null) ...[
        optional('fact_section', club!.sectionName),
        optional('fact_registered_by', club!.registeredByName),
        optional('fact_requested_at', date(club!.createdAt)),
      ] else if (member != null) ...[
        optional('fact_club', member!.clubName),
        row(
          'fact_insurance',
          (member!.insuranceVerified
                  ? 'supervision.union_camporees.insurance_verified'
                  : 'supervision.union_camporees.insurance_unverified')
              .tr(),
        ),
        optional('fact_requested_at', date(member!.createdAt)),
      ] else if (payment != null) ...[
        row('fact_amount', SacMoney.format(payment!.amount)),
        row('fact_type', _paymentTypeLabel(payment!.type)),
        optional('fact_club', payment!.clubName),
        optional('fact_reference', payment!.reference),
        // A calendar date: shown as stored, never shifted by the time zone.
        optional(
          'fact_paid_at',
          payment!.paidAt == null
              ? null
              : supervisionShortDate(context, payment!.paidAt!),
        ),
        optional('fact_notes', payment!.notes),
      ],
    ].whereType<SacValueRow>().toList();

    if (rows.isEmpty) return const SizedBox.shrink();
    return SacGroupedSection(
      label: 'supervision.union_camporees.facts_title'.tr(),
      dividerIndent: 16,
      // A count of rows says nothing here.
      action: const SizedBox.shrink(),
      children: rows,
    );
  }
}
