import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import '../../domain/entities/resource.dart';

/// Retorna el color asociado al tipo de recurso
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

/// Retorna el icono asociado al tipo de recurso
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

/// Retorna la etiqueta corta del tipo de recurso
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

/// Formatea el tamaño en bytes a string legible
String _formatFileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Card de recurso que muestra título, tipo, tamaño y fecha
class ResourceCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = resourceTypeColor(context, resource.resourceType);
    final icon = resourceTypeIcon(resource.resourceType);
    final label = resourceTypeLabel(resource.resourceType);
    final sizeStr = _formatFileSize(resource.fileSize);

    return Semantics(
      button: true,
      label: resource.title,
      child: SacCard(
        onTap: onTap,
        accentColor: color,
        animate: true,
        animationDelay: animationDelay,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Type icon ──────────────────────────────────────────
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  HugeIcon(
                    icon: icon,
                    size: 24,
                    color: color,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // ── Content ────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resource.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (resource.categoryName != null || sizeStr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (resource.categoryName != null)
                          _ResourceMetaPill(
                            label: resource.categoryName!,
                            color: color,
                          ),
                        if (sizeStr.isNotEmpty)
                          _ResourceMetaPill(
                            label: sizeStr,
                            color: c.textTertiary,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Chevron ────────────────────────────────────────────
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceMetaPill extends StatelessWidget {
  final String label;
  final Color color;

  const _ResourceMetaPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color == c.textTertiary ? c.textSecondary : color,
          fontWeight: FontWeight.w700,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
