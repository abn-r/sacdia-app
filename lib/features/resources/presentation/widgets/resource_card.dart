import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import '../../domain/entities/resource.dart';

/// Color semántico por tipo de recurso.
Color resourceTypeColor(BuildContext context, String resourceType) {
  final c = context.sac;

  switch (resourceType) {
    case 'audio':
      return c.warning;
    case 'image':
      return c.success;
    case 'video_link':
      return c.error;
    case 'text':
      return c.info;
    case 'document':
    default:
      return Theme.of(context).colorScheme.primary;
  }
}

List<List<dynamic>> resourceTypeIcon(String resourceType) {
  switch (resourceType) {
    case 'audio':
      return HugeIcons.strokeRoundedHeadphones;
    case 'image':
      return HugeIcons.strokeRoundedImage01;
    case 'video_link':
      return HugeIcons.strokeRoundedPlayCircle;
    case 'text':
      return HugeIcons.strokeRoundedTextWrap;
    case 'document':
    default:
      return HugeIcons.strokeRoundedFile01;
  }
}

String resourceTypeLabel(String resourceType) {
  switch (resourceType) {
    case 'audio':
      return 'resources.type_label.audio'.tr();
    case 'image':
      return 'resources.type_label.image'.tr();
    case 'video_link':
      return 'resources.type_label.video'.tr();
    case 'text':
      return 'resources.type_label.text'.tr();
    case 'document':
    default:
      return 'resources.type_label.document'.tr();
  }
}

String _formatFileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Card de recurso — un solo canal de tipo (icon tile tintado).
class ResourceCard extends StatefulWidget {
  final Resource resource;
  final VoidCallback onTap;
  final Duration animationDelay;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.onTap,
    this.animationDelay = Duration.zero,
  });

  @override
  State<ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends State<ResourceCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = resourceTypeColor(context, widget.resource.resourceType);
    final icon = resourceTypeIcon(widget.resource.resourceType);
    final sizeStr = _formatFileSize(widget.resource.fileSize);
    final reduce = SacMotion.reduceMotionOf(context);
    final meta = [
      if (widget.resource.categoryName != null) widget.resource.categoryName!,
      if (sizeStr.isNotEmpty) sizeStr,
    ].join(' · ');

    return Semantics(
      button: true,
      label: widget.resource.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.985 : 1,
          duration: SacMotion.press,
          curve: Curves.easeOut,
          child: SacCard(
            // Sin accent bar — el icon tile ya comunica el tipo.
            animate: true,
            animationDelay: widget.animationDelay,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: HugeIcon(
                    icon: icon,
                    size: 22,
                    color: color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.resource.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          height: 1.25,
                          letterSpacing: -0.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          meta,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: c.textTertiary,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
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
      ),
    );
  }
}
