import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/evidence_review_item.dart';

/// Card de un ítem pendiente de revisión de evidencia.
///
/// Muestra nombre del miembro, tipo, fecha de envío y cantidad de archivos.
class EvidenceReviewCard extends StatelessWidget {
  final EvidenceReviewItem item;
  final VoidCallback onTap;

  const EvidenceReviewCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final typeColor = _typeColor(item.type);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: c.shadow,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Avatar ──────────────────────────────────────────────────
              _MemberAvatar(
                name: item.memberName,
                photoUrl: item.memberPhotoUrl,
              ),
              const SizedBox(width: 12),

              // ── Content ─────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.memberName,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TypeBadge(type: item.type, color: typeColor),
                      ],
                    ),
                    if (item.context != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.context!,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar01,
                          size: 12,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('dd/MM/yyyy').format(
                            item.submittedAt.toLocal(),
                          ),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedAttachment01,
                          size: 12,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          (item.fileCount == 1
                                  ? 'coordinator.evidence_review.card.files_one'
                                  : 'coordinator.evidence_review.card.files_other')
                              .tr(namedArgs: {
                            'count': item.fileCount.toString()
                          }),
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Arrow ────────────────────────────────────────────────────
              const SizedBox(width: 8),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: c.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(EvidenceReviewType type) {
    switch (type) {
      case EvidenceReviewType.folder:
        return AppColors.accent;
      case EvidenceReviewType.classType:
        return AppColors.info;
      case EvidenceReviewType.honor:
        return AppColors.secondary;
    }
  }
}

class _TypeBadge extends StatelessWidget {
  final EvidenceReviewType type;
  final Color color;

  const _TypeBadge({required this.type, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type.displayLabel,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;

  const _MemberAvatar({required this.name, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';
    final theme = Theme.of(context);
    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: (photoUrl != null && photoUrl!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: photoUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 88,
                memCacheHeight: 88,
                placeholder: (_, __) => _initialsWidget(theme, initials),
                errorWidget: (_, __, ___) => _initialsWidget(theme, initials),
              )
            : _initialsWidget(theme, initials),
      ),
    );
  }

  Widget _initialsWidget(ThemeData theme, String initials) {
    return Container(
      color: theme.colorScheme.primaryContainer,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
