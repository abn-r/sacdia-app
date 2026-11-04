import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/transfer_request.dart';
import '../providers/transfer_providers.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Vista de detalle de una solicitud de traslado.
class TransferRequestDetailView extends ConsumerWidget {
  final String requestId;

  const TransferRequestDetailView({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync = ref.watch(transferRequestDetailProvider(requestId));
    final c = context.sac;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(title: tr('transfers.detail.title'), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => requestAsync.when(
            loading: () => const Center(child: SacLoading()),
            error: (e, _) => SacErrorState(
              title: userErrorMessage(e),
              padding:
                  SacTopBar.paddingBelowBar(context, const EdgeInsets.all(32)),
              onRetry: () =>
                  ref.invalidate(transferRequestDetailProvider(requestId)),
            ),
            data: (request) => _DetailBody(request: request),
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final TransferRequest request;

  const _DetailBody({required this.request});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final statusConfig = _statusConfig(context, request.status);
    final dateStr = request.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt!.toLocal())
        : '-';

    return ListView(
      padding: SacTopBar.paddingBelowBar(context, const EdgeInsets.all(20)),
      children: [
        // ── Status header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusConfig.bg,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: statusConfig.fg.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              HugeIcon(
                icon: statusConfig.icon,
                color: statusConfig.fg,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.status.label,
                      style: TextStyle(
                        fontSize: SacFontSize.headlineSmall,
                        fontWeight: FontWeight.w700,
                        color: statusConfig.fg,
                      ),
                    ),
                    Text(
                      tr(
                        'transfers.detail.request_number',
                        namedArgs: {'id': request.id},
                      ),
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: statusConfig.fg.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Details card ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              _DetailRow(
                icon: HugeIcons.strokeRoundedUserGroup,
                label: tr('transfers.detail.destination_section'),
                value: request.toSectionName ??
                    tr('transfers.list.section_number',
                        namedArgs: {'id': '${request.toSectionId}'}),
              ),
              if (request.toClubName != null) ...[
                Divider(height: 1, color: c.borderLight),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedBuilding01,
                  label: tr('transfers.detail.destination_club'),
                  value: request.toClubName!,
                ),
              ],
              Divider(height: 1, color: c.borderLight),
              _DetailRow(
                icon: HugeIcons.strokeRoundedCalendar01,
                label: tr('transfers.detail.request_date'),
                value: dateStr,
              ),
              if (request.reason != null) ...[
                Divider(height: 1, color: c.borderLight),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedMessage01,
                  label: tr('transfers.detail.reason'),
                  value: request.reason!,
                ),
              ],
            ],
          ),
        ),

        // ── Reviewer comment (visible only when rejected) ──────────────
        if (request.status == TransferStatus.rejected &&
            request.reviewerComment != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.errorContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: c.onErrorContainer.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedComment01,
                      color: c.onErrorContainer,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tr('transfers.detail.reviewer_comment'),
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        fontWeight: FontWeight.w600,
                        color: c.onErrorContainer,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  request.reviewerComment!,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    color: c.onErrorContainer,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  _TransferStatusConfig _statusConfig(
      BuildContext context, TransferStatus status) {
    final c = context.sac;
    switch (status) {
      case TransferStatus.approved:
        return _TransferStatusConfig(
          bg: c.successContainer,
          fg: c.onSuccessContainer,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case TransferStatus.rejected:
        return _TransferStatusConfig(
          bg: c.errorContainer,
          fg: c.onErrorContainer,
          icon: HugeIcons.strokeRoundedCancel01,
        );
      case TransferStatus.pending:
        return _TransferStatusConfig(
          bg: c.warningContainer,
          fg: c.onWarningContainer,
          icon: HugeIcons.strokeRoundedClock01,
        );
    }
  }
}

class _TransferStatusConfig {
  final Color bg;
  final Color fg;
  final HugeIconData icon;

  const _TransferStatusConfig({
    required this.bg,
    required this.fg,
    required this.icon,
  });
}

class _DetailRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, color: c.textTertiary, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    color: c.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: SacFontSize.titleSmall,
                    color: c.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
