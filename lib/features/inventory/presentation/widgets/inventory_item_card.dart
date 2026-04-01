import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/inventory_item.dart';
import 'condition_badge.dart';

/// Tarjeta de ítem de inventario con swipe actions opcionales.
///
/// Cuando [onEdit] y [onDelete] se proveen, la tarjeta se envuelve en
/// un [Dismissible] con swipe derecha = editar, swipe izquierda = eliminar.
/// Touch target mínimo: 72dp de alto.
class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const InventoryItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = _CardContent(item: item, onTap: onTap);

    if (onEdit != null || onDelete != null) {
      return Dismissible(
        key: ValueKey('inv-item-${item.id}'),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd && onEdit != null) {
            onEdit!();
            return false;
          }
          if (direction == DismissDirection.endToStart && onDelete != null) {
            onDelete!();
            return false;
          }
          return false;
        },
        background: _SwipeBackground(
          alignment: Alignment.centerLeft,
          color: AppColors.secondary.withValues(alpha: 0.15),
          icon: HugeIcons.strokeRoundedEdit01,
          iconColor: AppColors.secondary,
          label: 'Editar',
          labelColor: AppColors.secondary,
        ),
        secondaryBackground: _SwipeBackground(
          alignment: Alignment.centerRight,
          color: AppColors.error.withValues(alpha: 0.12),
          icon: HugeIcons.strokeRoundedDelete02,
          iconColor: AppColors.error,
          label: 'Eliminar',
          labelColor: AppColors.error,
        ),
        child: card,
      );
    }

    return card;
  }
}

// ── Card content ────────────────────────────────────────────────────────────────

class _CardContent extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;

  const _CardContent({required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: c.border.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Thumbnail 60x60
            _ItemThumbnail(photoUrl: item.photoUrl),

            const SizedBox(width: 12),

            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          height: 1.2,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 5),

                  // Category tag + condition badge side by side
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.category.name,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ConditionBadge(condition: item.condition, compact: true),
                    ],
                  ),

                  const SizedBox(height: 5),

                  // Quantity + location row
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPackage,
                        size: 12,
                        color: c.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Cant: ${item.quantity}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.textSecondary,
                              fontSize: 11,
                            ),
                      ),
                      if (item.location != null &&
                          item.location!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedLocation01,
                          size: 12,
                          color: c.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.location!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: c.textSecondary,
                                  fontSize: 11,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      if (item.estimatedValue != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '\$${_formatValue(item.estimatedValue!)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Chevron
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 16,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Thumbnail ───────────────────────────────────────────────────────────────────

class _ItemThumbnail extends StatelessWidget {
  final String? photoUrl;

  const _ItemThumbnail({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    const size = 60.0;
    const radius = 14.0;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, __) => _Placeholder(size: size),
          errorWidget: (_, __, ___) => _Placeholder(size: size),
        ),
      );
    }

    return _Placeholder(size: size);
  }
}

class _Placeholder extends StatelessWidget {
  final double size;

  const _Placeholder({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBoxingBag,
          size: 28,
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

// ── Swipe background ────────────────────────────────────────────────────────────

class _SwipeBackground extends StatelessWidget {
  final Alignment alignment;
  final Color color;
  final HugeIconData icon;
  final Color iconColor;
  final String label;
  final Color labelColor;

  const _SwipeBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon: icon, size: 20, color: iconColor),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: labelColor,
            ),
          ),
        ],
      ),
    );
  }
}
