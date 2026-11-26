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
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_error_state.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_list_row.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_tone.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_value_row.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_grouped_section.dart';
import 'package:sacdia_app/features/auth/domain/utils/authorization_utils.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/supervision/domain/entities/supervision_union_camporee.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_action_result.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/providers/supervision_union_camporees_providers.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_actions.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_decision_sheet.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_format.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_messages.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_row_parts.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_scroll.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_segmented_control.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_status_chip.dart';
import 'package:sacdia_app/features/supervision/presentation/widgets/supervision_voucher_card.dart';
import 'package:sacdia_app/features/transfers/presentation/widgets/club_type_tile.dart';
import 'package:sacdia_app/core/theme/club_type.dart';

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
    final rows = <Widget>[
      ...switch (kind) {
        SupervisionCamporeeApprovalKind.club => [
            for (final club in pending.clubs)
              _ClubRow(
                key: ValueKey('club-${club.id}'),
                club: club,
                onTap: () => _showItem(
                  context,
                  _ItemSheet.club(camporeeId: camporeeId, club: club),
                ),
              ),
          ],
        SupervisionCamporeeApprovalKind.member => [
            for (final member in pending.members)
              _MemberRow(
                key: ValueKey('member-${member.id}'),
                member: member,
                onTap: () => _showItem(
                  context,
                  _ItemSheet.member(camporeeId: camporeeId, member: member),
                ),
              ),
          ],
        SupervisionCamporeeApprovalKind.payment => [
            for (final payment in pending.payments)
              _PaymentRow(
                key: ValueKey('payment-${payment.id}'),
                payment: payment,
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
                const EdgeInsets.only(top: 0),
              ),
              sliver: SliverToBoxAdapter(
                child: SupervisionSegmentedControl<
                    SupervisionCamporeeApprovalKind>(
                  selected: kind,
                  onChanged: onKind,
                  segments: [
                    SupervisionSegment(
                      value: SupervisionCamporeeApprovalKind.club,
                      label: 'supervision.union_camporees.kind_clubs'.tr(),
                      count: pending.clubs.length,
                    ),
                    SupervisionSegment(
                      value: SupervisionCamporeeApprovalKind.member,
                      label: 'supervision.union_camporees.kind_members'.tr(),
                      count: pending.members.length,
                    ),
                    SupervisionSegment(
                      value: SupervisionCamporeeApprovalKind.payment,
                      label: 'supervision.union_camporees.kind_payments'.tr(),
                      count: pending.payments.length,
                    ),
                  ],
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
                  sliver: rows.isEmpty
                      ? SliverFillRemaining(
                          hasScrollBody: false,
                          child: SacEmptyState(
                            title:
                                'supervision.union_camporees.kind_empty_title'
                                    .tr(),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.only(bottom: 32),
                          sliver: SliverToBoxAdapter(
                            child: SacGroupedSection(
                              label:
                                  'supervision.union_camporees.late_label'.tr(),
                              children: rows,
                            ),
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

class _ClubRow extends StatelessWidget {
  const _ClubRow({super.key, required this.club, required this.onTap});

  final SupervisionCamporeePendingClub club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = _orUnnamed(
      club.clubName,
      'supervision.union_camporees.unknown_club',
    );
    // Without a known club-type logo the tile shows the monogram.
    final hasLogo = clubLogoAssetFromName(club.sectionName) != null;
    final monogram = SacMemberAvatar.initialsOf(club.clubName);
    return SacListRow(
      leading: ClubTypeTile(
        clubTypeName: club.sectionName,
        initials: hasLogo || monogram.isEmpty ? null : monogram,
      ),
      title: title,
      subtitle: club.sectionName,
      trailing: SupervisionRowAge(when: club.createdAt),
      onTap: onTap,
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({super.key, required this.member, required this.onTap});

  final SupervisionCamporeePendingMember member;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = _orUnnamed(
      member.fullName,
      'supervision.union_camporees.unknown_member',
    );
    return SacListRow(
      leading: ExcludeSemantics(
        child: SacMemberAvatar(name: member.fullName, size: 40),
      ),
      title: name,
      subtitleWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (member.clubName.trim().isNotEmpty)
            Text(
              member.clubName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.3,
                color: c.textSecondary,
              ),
            ),
          const SizedBox(height: 6),
          _InsuranceChip(verified: member.insuranceVerified),
        ],
      ),
      trailing: SupervisionRowAge(when: member.createdAt),
      onTap: onTap,
    );
  }
}

/// «Seguro verificado» (green) or «Seguro sin verificar» (amber): what the
/// reviewer must not miss when approving a member.
class _InsuranceChip extends StatelessWidget {
  const _InsuranceChip({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    return SupervisionStatusChip(
      label: (verified
              ? 'supervision.union_camporees.insurance_verified'
              : 'supervision.union_camporees.insurance_unverified')
          .tr(),
      icon: HugeIcons.strokeRoundedShield01,
      tone: verified ? SacTone.success : SacTone.warning,
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({super.key, required this.payment, required this.onTap});

  final SupervisionCamporeePendingPayment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final type = _paymentTypeLabel(payment.type);
    final reference = payment.reference?.trim() ?? '';
    return SacListRow(
      leading: const SacListRowIcon(HugeIcons.strokeRoundedMoney01),
      title: _paymentTitle(payment),
      subtitle: reference.isEmpty
          ? type
          : 'supervision.union_camporees.payment_ref'
              .tr(args: [type, reference]),
      trailing: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SupervisionTrailingFit(
            child: Text(
              SacMoney.format(payment.amount),
              maxLines: 1,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                fontWeight: FontWeight.w700,
                color: c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          SupervisionRowAge(when: payment.createdAt),
        ],
      ),
      onTap: onTap,
    );
  }
}

/// A payment is named after its club; the payer is the fallback.
String _paymentTitle(SupervisionCamporeePendingPayment payment) =>
    payment.clubName.trim().isNotEmpty
        ? payment.clubName
        : _orUnnamed(
            payment.memberName,
            'supervision.union_camporees.unknown_club',
          );

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
    if (widget.payment != null) return _paymentTitle(widget.payment!);
    return _orUnnamed(
      widget.club?.clubName ?? widget.member?.fullName ?? '',
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

  /// Approving needs no second dialog: the sheet already shows everything
  /// that is being approved. Rejecting asks for the reason first.
  Future<void> _decide({required bool approve}) async {
    final what = _isPayment ? 'payment' : 'registration';
    String? reason;
    if (!approve) {
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
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final canDecide =
        hasCapability(user, 'union_camporees.approve_registrations');
    final payment = widget.payment;
    final voucher = payment?.voucherUrl?.trim() ?? '';

    final String title;
    final String subtitle;
    if (payment != null) {
      title =
          'supervision.union_camporees.sheet_payment_title'.tr(args: [_name]);
      subtitle = [
        _paymentTypeLabel(payment.type),
        if (payment.paidAt != null)
          'supervision.union_camporees.paid_on'
              .tr(args: [supervisionShortDate(context, payment.paidAt!)]),
      ].join(' · ');
    } else {
      title = _name;
      subtitle = (widget.club != null
              ? 'supervision.union_camporees.sheet_club'
              : 'supervision.union_camporees.sheet_member')
          .tr();
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(title: title, subtitle: subtitle),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (payment != null) _BigAmount(amount: payment.amount),
                  if (voucher.isNotEmpty)
                    SupervisionVoucherCard(
                      url: voucher,
                      onTap: () => _openVoucher(voucher),
                    ),
                  _ItemFacts(
                    club: widget.club,
                    member: widget.member,
                    payment: payment,
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) SupervisionInlineError(message: _error!),
          if (canDecide)
            SupervisionSheetFooter(
              child: SupervisionStackedActions(
                primaryLabel: (_isPayment
                        ? 'supervision.union_camporees.approve_payment_action'
                        : 'supervision.union_camporees.approve_registration_action')
                    .tr(),
                primaryIcon: HugeIcons.strokeRoundedTick02,
                onPrimary: () => _decide(approve: true),
                secondaryLabel: 'coordinator.actions.reject'.tr(),
                secondaryIcon: HugeIcons.strokeRoundedCancel01,
                onSecondary: () => _decide(approve: false),
                isLoading: _busy,
              ),
            )
          else
            const SafeArea(top: false, child: SizedBox(height: 4)),
        ],
      ),
    );
  }
}

/// The amount of a payment, large, at the top of its sheet.
class _BigAmount extends StatelessWidget {
  const _BigAmount({required this.amount});

  final double amount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Text(
        SacMoney.format(amount),
        style: TextStyle(
          fontSize: SacFontSize.displaySmall,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.15,
          color: context.sac.text,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
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
        optional('fact_payer', payment!.memberName),
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
