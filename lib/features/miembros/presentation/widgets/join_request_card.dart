import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

import '../../domain/entities/join_request.dart';

/// Tarjeta de solicitud de ingreso al club
class JoinRequestCard extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  const JoinRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.onApprove,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isPending = request.status == JoinRequestStatus.pending;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header row ────────────────────────────────────────
              Row(
                children: [
                  // Avatar
                  _RequestAvatar(request: request),

                  const SizedBox(width: 12),

                  // Name + date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.fullName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (request.requestedAt != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              HugeIcon(
                                icon: HugeIcons.strokeRoundedCalendar01,
                                color: c.textTertiary,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('dd MMM yyyy')
                                    .format(request.requestedAt!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status badge
                  _StatusBadge(status: request.status),
                ],
              ),

              // ── Actions (only for pending) ────────────────────────
              if (isPending && (onApprove != null || onReject != null)) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onReject != null)
                      Expanded(
                        child: _ActionButton(
                          label: 'Rechazar',
                          icon: HugeIcons.strokeRoundedCancel01,
                          color: AppColors.error,
                          onTap: onReject!,
                          outlined: true,
                        ),
                      ),
                    if (onApprove != null && onReject != null)
                      const SizedBox(width: 8),
                    if (onApprove != null)
                      Expanded(
                        child: _ActionButton(
                          label: 'Aprobar',
                          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                          color: AppColors.secondary,
                          onTap: onApprove!,
                          outlined: false,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestAvatar extends StatelessWidget {
  final JoinRequest request;

  const _RequestAvatar({required this.request});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.accentLight,
          width: 2,
        ),
      ),
      child: CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.accentLight,
        backgroundImage:
            request.avatar != null ? NetworkImage(request.avatar!) : null,
        child: request.avatar == null
            ? Text(
                request.initials,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentDark,
                ),
              )
            : null,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final JoinRequestStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case JoinRequestStatus.pending:
        return const SacBadge.warning(label: 'Pendiente');
      case JoinRequestStatus.approved:
        return const SacBadge.success(label: 'Aprobado');
      case JoinRequestStatus.rejected:
        return const SacBadge.error(label: 'Rechazado');
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final List<List<dynamic>> icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: HugeIcon(icon: icon, color: color, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color, width: 1.5),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: HugeIcon(icon: icon, color: Colors.white, size: 16),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
