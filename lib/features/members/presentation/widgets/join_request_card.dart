import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/join_request.dart';

/// Compact join-request row. Approve/reject sit as trailing icon hits, not a second button row.
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
    final canAct = isPending && (onApprove != null || onReject != null);
    final dateLabel = request.requestedAt == null
        ? null
        : DateFormat('dd MMM yyyy').format(request.requestedAt!.toLocal());

    return SacPressable(
      onTap: onTap,
      enabled: onTap != null,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            _RequestAvatar(request: request),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    request.fullName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (dateLabel != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      dateLabel,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.2,
                        color: c.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (canAct) ...[
              if (onReject != null)
                _IconAction(
                  semanticLabel: 'members.join_request.reject'.tr(),
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: AppColors.error,
                  background: AppColors.error.withValues(alpha: 0.10),
                  onTap: onReject!,
                ),
              if (onApprove != null)
                _IconAction(
                  semanticLabel: 'members.join_request.approve'.tr(),
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  color: AppColors.secondary,
                  background: AppColors.secondary.withValues(alpha: 0.12),
                  onTap: onApprove!,
                ),
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
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: SizedBox(
          width: 36,
          height: 36,
          child: request.avatar != null
              ? SacProfileImage(
                  imageUrl: request.avatar!,
                  fit: BoxFit.cover,
                  memCacheWidth: 72,
                  memCacheHeight: 72,
                  placeholder: (_, __) => _AvatarInitials(
                    initials: request.initials,
                  ),
                  errorWidget: (_, __, ___) => _AvatarInitials(
                    initials: request.initials,
                  ),
                )
              : _AvatarInitials(initials: request.initials),
        ),
      ),
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;

  const _AvatarInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.accentLight,
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.accentDark,
          ),
        ),
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
  final List<List<dynamic>> icon;
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
        width: 40,
        height: 40,
        child: Center(
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
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
