import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/join_request.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Compact join-request row. Approve/reject sit as trailing icon hits, not a second button row.
class JoinRequestCard extends StatelessWidget {
  final JoinRequest request;
  final VoidCallback? onTap;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  /// Abre la verificación de la ficha de un menor sin ofrecer aprobar ni
  /// rechazar (revisor con solo `consent:verify`).
  final VoidCallback? onVerify;

  /// Línea extra bajo el nombre (p. ej. "club · tipo · distrito" en la cola del
  /// coordinador, donde las fichas de varias secciones van mezcladas).
  final String? caption;

  const JoinRequestCard({
    super.key,
    required this.request,
    this.onTap,
    this.onApprove,
    this.onReject,
    this.onVerify,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isPending = request.status == JoinRequestStatus.pending;
    final consent = request.consent;
    final needsVerification = request.consentPending;
    // `onVerify` solo aplica a un menor con la ficha por verificar.
    final primary = needsVerification ? (onVerify ?? onApprove) : onApprove;
    final canAct = isPending && (primary != null || onReject != null);
    final dateLabel = request.requestedAt == null
        ? null
        : DateFormat('dd MMM yyyy').format(request.requestedAt!.toLocal());

    return SacPressable(
      onTap: onTap,
      enabled: onTap != null,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SacMemberAvatar(
              imageUrl: request.avatar,
              name: request.fullName,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request.fullName,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (caption != null && caption!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      caption!,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.2,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (dateLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        height: 1.2,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (consent != null) ...[
                    const SizedBox(height: 6),
                    _ConsentBadge(consent: consent),
                  ],
                ],
              ),
            ),
            if (canAct) ...[
              if (onReject != null) ...[
                const SizedBox(width: 4),
                _IconAction(
                  semanticLabel: 'members.join_request.reject'.tr(),
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: c.onErrorContainer,
                  background: c.errorContainer,
                  onTap: onReject!,
                ),
              ],
              if (primary != null) ...[
                const SizedBox(width: 8),
                _IconAction(
                  // Un menor sin ficha verificada no se aprueba directo: el
                  // mismo botón abre la verificación (FP-76).
                  semanticLabel: needsVerification
                      ? 'members.consent.verify_action'.tr()
                      : 'members.join_request.approve'.tr(),
                  icon: needsVerification
                      ? HugeIcons.strokeRoundedFileVerified
                      : HugeIcons.strokeRoundedCheckmarkCircle01,
                  color: c.onSuccessContainer,
                  background: c.successContainer,
                  onTap: primary,
                ),
              ],
            ] else ...[
              const SizedBox(width: 8),
              _StatusBadge(status: request.status),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Menor · consentimiento pendiente/verificado" (solo menores sin cuenta).
class _ConsentBadge extends StatelessWidget {
  final JoinRequestConsent consent;

  const _ConsentBadge({required this.consent});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: consent.isVerified
          ? SacBadge.success(
              label: 'members.consent.badge_verified'.tr(),
              icon: HugeIcons.strokeRoundedCheckmarkBadge01,
            )
          : SacBadge.warning(
              label: 'members.consent.badge_pending'.tr(),
              icon: HugeIcons.strokeRoundedClock01,
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
        return SacBadge.warning(label: 'members.common.pending'.tr());
      case JoinRequestStatus.approved:
        return SacBadge.success(label: 'members.join_request.approved'.tr());
      case JoinRequestStatus.rejected:
        return SacBadge.error(label: 'members.join_request.rejected'.tr());
    }
  }
}

class _IconAction extends StatelessWidget {
  final String semanticLabel;
  final HugeIconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _IconAction({
    required this.semanticLabel,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
            ),
            child: Center(
              child: HugeIcon(
                icon: icon,
                color: color,
                size: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
