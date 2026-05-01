import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import '../../domain/entities/resource.dart';

/// Retorna el color asociado al tipo de recurso
Color resourceTypeColor(String resourceType) {
  switch (resourceType) {
    case 'audio':
      return AppColors.accent;
    case 'image':
      return AppColors.secondary;
    case 'video_link':
      return const Color(0xFFE53935);
    case 'text':
      return AppColors.sacBlue;
    case 'document':
    default:
      return AppColors.primary;
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

  const ResourceCard({
    super.key,
    required this.resource,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = resourceTypeColor(resource.resourceType);
    final icon = resourceTypeIcon(resource.resourceType);
    final label = resourceTypeLabel(resource.resourceType);
    final sizeStr = _formatFileSize(resource.fileSize);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // ── Type icon ──────────────────────────────────────
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusSM),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      HugeIcon(
                        icon: icon,
                        size: 22,
                        color: color,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 3, vertical: 1),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(
                                AppTheme.radiusXS),
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 6,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // ── Content ────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (resource.categoryName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          resource.categoryName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (sizeStr.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          sizeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // ── Chevron ────────────────────────────────────────
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
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
