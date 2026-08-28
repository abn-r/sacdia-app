import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import '../../domain/entities/resource.dart';
import '../providers/resources_providers.dart';
import '../utils/resource_preview.dart';

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

/// Tile de recurso en grilla: preview + título.
class ResourceCard extends ConsumerStatefulWidget {
  final Resource resource;
  final VoidCallback onTap;

  const ResourceCard({
    super.key,
    required this.resource,
    required this.onTap,
  });

  @override
  ConsumerState<ResourceCard> createState() => _ResourceCardState();
}

class _ResourceCardState extends ConsumerState<ResourceCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final resource = widget.resource;
    final sizeStr = _formatFileSize(resource.fileSize);
    final reduce = SacMotion.reduceMotionOf(context);
    final meta = [
      if (resource.categoryName != null) resource.categoryName!,
      if (sizeStr.isNotEmpty) sizeStr,
    ].join(' · ');

    final cachedSigned = resource.signedUrl;
    final shouldFetch = resourceWantsSignedPreview(resource);
    final fetched = shouldFetch
        ? ref.watch(resourcePreviewSignedUrlProvider(resource.resourceId))
        : null;
    final imageUrl = (cachedSigned != null && cachedSigned.isNotEmpty)
        ? cachedSigned
        : fetched?.valueOrNull;
    final videoThumb = videoPreviewUrl(resource.externalUrl);

    return Semantics(
      button: true,
      label: '${resource.title}, ${resourceTypeLabel(resource.resourceType)}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? 0.97 : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(color: c.border),
              boxShadow: [
                BoxShadow(
                  color: c.shadow,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ResourcePreviewPane(
                    resource: resource,
                    imageUrl: imageUrl,
                    videoThumbUrl: videoThumb,
                    isImageLoading: fetched?.isLoading ?? false,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          height: 1.2,
                          letterSpacing: -0.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          style: TextStyle(
                            fontSize: 11,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResourcePreviewPane extends StatelessWidget {
  final Resource resource;
  final String? imageUrl;
  final String? videoThumbUrl;
  final bool isImageLoading;
  final bool showTypeBadge;
  final int textMaxLines;

  const ResourcePreviewPane({
    super.key,
    required this.resource,
    required this.imageUrl,
    required this.videoThumbUrl,
    required this.isImageLoading,
    this.showTypeBadge = true,
    this.textMaxLines = 6,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final color = resourceTypeColor(context, resource.resourceType);
    final icon = resourceTypeIcon(resource.resourceType);

    return ColoredBox(
      color: color.withValues(alpha: 0.12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _previewBody(context, c, color, icon),
          if (showTypeBadge)
            Positioned(
              top: 8,
              left: 8,
              child: _TypeBadge(
                label: resourceTypeLabel(resource.resourceType),
              ),
            ),
          if (resource.resourceType == 'video_link')
            Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const HugeIcon(
                  icon: HugeIcons.strokeRoundedPlay,
                  size: 18,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _previewBody(
    BuildContext context,
    SacColors c,
    Color color,
    List<List<dynamic>> icon,
  ) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return SacNetworkImage(
        imageUrl: imageUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 800,
        placeholder: (_, __) => _TypeGlyph(color: color, icon: icon),
        errorWidget: (_, __, ___) => _TypeGlyph(color: color, icon: icon),
      );
    }

    if (resource.resourceType == 'video_link' &&
        videoThumbUrl != null &&
        videoThumbUrl!.isNotEmpty) {
      return SacNetworkImage(
        imageUrl: videoThumbUrl!,
        fit: BoxFit.cover,
        memCacheWidth: 800,
        placeholder: (_, __) => _TypeGlyph(color: color, icon: icon),
        errorWidget: (_, __, ___) => _TypeGlyph(color: color, icon: icon),
      );
    }

    if (resource.resourceType == 'text' &&
        resource.content != null &&
        resource.content!.trim().isNotEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(12, showTypeBadge ? 36 : 16, 12, 12),
        child: Text(
          resource.content!.trim(),
          maxLines: textMaxLines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: c.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (isImageLoading) {
      return _TypeGlyph(color: color, icon: icon);
    }

    return _TypeGlyph(
      color: color,
      icon: icon,
      caption: resource.fileName,
    );
  }
}

class _TypeGlyph extends StatelessWidget {
  final Color color;
  final List<List<dynamic>> icon;
  final String? caption;

  const _TypeGlyph({
    required this.color,
    required this.icon,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 28, 12, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon: icon, size: 36, color: color),
          if (caption != null && caption!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              caption!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: c.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;

  const _TypeBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.1,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
