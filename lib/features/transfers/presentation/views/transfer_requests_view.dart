import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_frosted_footer.dart';
import '../../../../core/widgets/sac_list_row.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../auth/domain/entities/authorization_snapshot.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/transfer_request.dart';
import '../providers/transfer_providers.dart';
import '../widgets/club_type_tile.dart';
import '../widgets/transfer_status.dart';
import 'transfer_club_picker_view.dart';

/// "Cambiar de club": the club the member is in, the request in review (if
/// any), past requests and the action to ask for a new club.
class TransferRequestsView extends ConsumerWidget {
  const TransferRequestsView({super.key});

  /// Opens the club picker of a new request.
  static void openNewRequest(BuildContext context) {
    Navigator.of(context).push(
      SacSharedAxisRoute(builder: (_) => const TransferClubPickerView()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final requestsAsync = ref.watch(myTransferRequestsProvider);
    final grant = ref.watch(
      authNotifierProvider.select(
        (value) => value.value?.authorization?.activeGrant,
      ),
    );
    final requests = requestsAsync.value;
    final pending =
        requests?.where((r) => r.status == TransferStatus.pending).firstOrNull;
    final hasMembership = grant?.sectionId != null && grant?.clubTypeId != null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'transfers.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: requestsAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => SacErrorState(
          title: userErrorMessage(e),
          onRetry: () => ref.invalidate(myTransferRequestsProvider),
        ),
        data: (requests) => RefreshIndicator(
          color: SacAccent.of(context).color,
          onRefresh: () async {
            ref.invalidate(myTransferRequestsProvider);
            await ref
                .read(myTransferRequestsProvider.future)
                .catchError((_) => const <TransferRequest>[]);
          },
          child: _Body(requests: requests, pending: pending, grant: grant),
        ),
      ),
      bottomNavigationBar: requests == null
          ? null
          : SacFrostedFooter(
              note: pending != null
                  ? 'transfers.list.pending_note'.tr()
                  : !hasMembership
                      ? 'transfers.form.no_active_membership'.tr()
                      : null,
              child: SacButton.primary(
                key: const ValueKey('transfer-request-new'),
                text: 'transfers.list.request'.tr(),
                icon: HugeIcons.strokeRoundedArrowDataTransferHorizontal,
                onPressed: pending == null && hasMembership
                    ? () => TransferRequestsView.openNewRequest(context)
                    : null,
              ),
            ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.requests,
    required this.pending,
    required this.grant,
  });

  final List<TransferRequest> requests;
  final TransferRequest? pending;
  final AuthorizationGrant? grant;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final pending = this.pending;
    final grant = this.grant;
    final history = [
      for (final r in requests)
        if (r.status != TransferStatus.pending) r,
    ];
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        if (pending != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _PendingPanel(request: pending),
          ),
        if (grant != null && grant.clubName != null) ...[
          SacGroupedSection(
            label: 'transfers.list.current_club'.tr(),
            action: const SizedBox.shrink(),
            children: [
              SacListRow(
                key: const ValueKey('transfer-current-club'),
                leading: ClubTypeTile(clubTypeName: grant.clubTypeName),
                title: grant.clubName!,
                subtitle: [
                  if (grant.clubTypeName != null) grant.clubTypeName!,
                  if (grant.localFieldName != null) grant.localFieldName!,
                ].join(' · '),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
            child: Text(
              'transfers.list.keeps'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                height: 1.4,
                color: c.textSecondary,
              ),
            ),
          ),
        ],
        if (history.isNotEmpty)
          SacGroupedSection(
            label: 'transfers.list.history'.tr(),
            children: [
              for (final r in history)
                SacStatusRow(
                  key: ValueKey('transfer-row-${r.id}'),
                  style: transferStatusStyle(context, r.status),
                  title: 'transfers.list.to_club'
                      .tr(namedArgs: {'club': transferDestination(r)}),
                  detail: [
                    'transfers.status.${r.status.slug}'.tr(),
                    if (r.createdAt != null)
                      transferDate(context, r.createdAt!),
                  ].join(' · '),
                  detailIsError: r.status == TransferStatus.rejected,
                  onTap: () =>
                      context.push(RouteNames.transferRequestDetail(r.id)),
                ),
            ],
          ),
      ],
    );
  }
}

/// The request in review, first: where it went and when.
class _PendingPanel extends StatelessWidget {
  const _PendingPanel({required this.request});

  final TransferRequest request;

  @override
  Widget build(BuildContext context) {
    final club = transferDestination(request);
    final created = request.createdAt;
    return SacStatePanel(
      key: const ValueKey('transfer-pending-panel'),
      style: transferStatusStyle(context, request.status),
      title: 'transfers.status.pending'.tr(),
      message: [
        if (created != null)
          'transfers.list.pending_sent'.tr(namedArgs: {
            'club': club,
            'date': transferDate(context, created),
          }),
        'transfers.detail.pending_message'.tr(namedArgs: {'club': club}),
      ].join(' '),
      stepLabel:
          'transfers.states.step'.tr(namedArgs: {'step': '2', 'total': '3'}),
      onTap: () => context.push(RouteNames.transferRequestDetail(request.id)),
    );
  }
}
