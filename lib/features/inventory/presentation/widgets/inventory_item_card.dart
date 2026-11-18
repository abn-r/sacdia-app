import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_network_image.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/inventory_item.dart';
import 'condition_style.dart';

/// Row of an inventory item inside a grouped list.
///
/// Photo (or a tile tinted with the condition icon), the full name, and a
/// detail line "● Estado · N piezas · Ubicación". Every action lives in the
/// trailing "more" button ([onMore]); there is no swipe.
class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback? onTap;

  /// Opens the actions sheet. Null hides the button (read-only roles).
  final VoidCallback? onMore;

  const InventoryItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onMore,
  });

  /// Touch target of the trailing button and the minimum row height.
  static const double target = 44;
  static const double imageSize = 46;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacInkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 68),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              14, 10, onMore == null ? 14 : 4, 10),
          child: Row(
            children: [
              InventoryItemImage(item: item),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _DetailLine(item: item),
                  ],
                ),
              ),
              if (onMore != null)
                SacPressable(
                  listenOnly: true,
                  child: IconButton(
                    key: ValueKey('inventory-more-${item.id}'),
                    enableFeedback: false,
                    tooltip: 'inventory.view.more_options'.tr(),
                    constraints: const BoxConstraints.tightFor(
                      width: target,
                      height: target,
                    ),
                    onPressed: onMore,
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedMoreHorizontal,
                      size: 20,
                      color: c.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final InventoryItem item;

  const _DetailLine({required this.item});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final location = item.location?.trim();
    final muted = TextStyle(
      fontSize: SacFontSize.bodySmall,
      height: 1.3,
      color: c.textSecondary,
    );

    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          TextSpan(
            text: '● ',
            style: TextStyle(color: item.condition.dotColor(c)),
          ),
          TextSpan(
            text: item.condition.shortLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: item.condition.onContainer(c),
            ),
          ),
          TextSpan(
            text: ' · ${'inventory.view.pieces'.plural(
              item.quantity,
              name: 'count',
            )}',
          ),
          if (location != null && location.isNotEmpty)
            TextSpan(text: ' · $location'),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// 46px square: the item photo, or a tile tinted with the condition icon.
class InventoryItemImage extends StatelessWidget {
  final InventoryItem item;
  final double size;

  const InventoryItemImage({
    super.key,
    required this.item,
    this.size = InventoryItemCard.imageSize,
  });

  @override
  Widget build(BuildContext context) {
    final url = item.photoUrl;
    final placeholder = _TintedTile(condition: item.condition, size: size);

    if (url == null || url.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      child: SacNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        memCacheWidth: (size * 3).round(),
        memCacheHeight: (size * 3).round(),
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _TintedTile extends StatelessWidget {
  final ItemCondition condition;
  final double size;

  const _TintedTile({required this.condition, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: condition.container(c),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Center(
        child: HugeIcon(
          icon: condition.icon,
          size: size * 0.46,
          color: condition.onContainer(c),
        ),
      ),
    );
  }
}
