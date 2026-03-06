import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/inventory_item.dart';
import 'condition_badge.dart';

/// Tarjeta que muestra un ítem de inventario en la lista.
class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;

  const InventoryItemCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo thumbnail / placeholder
            _ItemThumbnail(photoUrl: item.photoUrl),

            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + condition
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: context.sac.text,
                                  ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ConditionBadge(
                        condition: item.condition,
                        compact: true,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.category.name,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Quantity + location row
                  Row(
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedPackage,
                        size: 13,
                        color: context.sac.textTertiary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Cant: ${item.quantity}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.sac.textSecondary,
                              fontSize: 11,
                            ),
                      ),
                      if (item.location != null) ...[
                        const SizedBox(width: 10),
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedLocation01,
                          size: 13,
                          color: context.sac.textTertiary,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            item.location!,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.sac.textSecondary,
                                      fontSize: 11,
                                    ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Estimated value (if present)
                  if (item.estimatedValue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedMoney01,
                            size: 13,
                            color: context.sac.textTertiary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '\$${item.estimatedValue!.toStringAsFixed(2)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: context.sac.textSecondary,
                                      fontSize: 11,
                                    ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 4),

            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 16,
              color: context.sac.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Thumbnail widget ────────────────────────────────────────────────────────────

class _ItemThumbnail extends StatelessWidget {
  final String? photoUrl;

  const _ItemThumbnail({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    const size = 52.0;
    const radius = 12.0;

    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          photoUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _Placeholder(size: size),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedBoxingBag,
          size: 26,
          color: AppColors.primary.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
