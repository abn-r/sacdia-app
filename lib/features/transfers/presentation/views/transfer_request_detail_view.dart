import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/transfer_request.dart';
import '../providers/transfer_providers.dart';

/// Vista de detalle de una solicitud de traslado.
class TransferRequestDetailView extends ConsumerWidget {
  final int requestId;

  const TransferRequestDetailView({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestAsync =
        ref.watch(transferRequestDetailProvider(requestId));
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Detalle de traslado',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: c.text,
          ),
        ),
        centerTitle: false,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: c.text,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: requestAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  e.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: c.textSecondary),
                ),
                const SizedBox(height: 16),
                SacButton.primary(
                  text: 'Reintentar',
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: () =>
                      ref.invalidate(transferRequestDetailProvider(requestId)),
                ),
              ],
            ),
          ),
        ),
        data: (request) => _DetailBody(request: request),
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
    final statusConfig = _statusConfig(request.status);
    final dateStr = request.createdAt != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(request.createdAt!)
        : '-';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // ── Status header ──────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusConfig.bg,
            borderRadius: BorderRadius.circular(14),
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
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: statusConfig.fg,
                      ),
                    ),
                    Text(
                      'Solicitud #${request.id}',
                      style: TextStyle(
                        fontSize: 12,
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
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              _DetailRow(
                icon: HugeIcons.strokeRoundedUserGroup,
                label: 'Sección destino',
                value: request.toSectionName ?? 'Sección #${request.toSectionId}',
              ),
              if (request.toClubName != null) ...[
                Divider(height: 1, color: c.borderLight),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedBuilding01,
                  label: 'Club destino',
                  value: request.toClubName!,
                ),
              ],
              Divider(height: 1, color: c.borderLight),
              _DetailRow(
                icon: HugeIcons.strokeRoundedCalendar01,
                label: 'Fecha de solicitud',
                value: dateStr,
              ),
              if (request.reason != null) ...[
                Divider(height: 1, color: c.borderLight),
                _DetailRow(
                  icon: HugeIcons.strokeRoundedMessage01,
                  label: 'Motivo',
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
              color: AppColors.errorLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedComment01,
                      color: AppColors.errorDark,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Comentario del revisor',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.errorDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  request.reviewerComment!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.errorDark,
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

  _TransferStatusConfig _statusConfig(TransferStatus status) {
    switch (status) {
      case TransferStatus.approved:
        return _TransferStatusConfig(
          bg: AppColors.secondaryLight,
          fg: AppColors.secondaryDark,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case TransferStatus.rejected:
        return _TransferStatusConfig(
          bg: AppColors.errorLight,
          fg: AppColors.errorDark,
          icon: HugeIcons.strokeRoundedCancel01,
        );
      case TransferStatus.pending:
        return _TransferStatusConfig(
          bg: AppColors.accentLight,
          fg: AppColors.accentDark,
          icon: HugeIcons.strokeRoundedClock01,
        );
    }
  }
}

class _TransferStatusConfig {
  final Color bg;
  final Color fg;
  final dynamic icon;

  const _TransferStatusConfig({
    required this.bg,
    required this.fg,
    required this.icon,
  });
}

class _DetailRow extends StatelessWidget {
  final dynamic icon;
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
                    fontSize: 11,
                    color: c.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
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
