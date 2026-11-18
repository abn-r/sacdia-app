import 'dart:ui' show ImageFilter;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_network_image.dart';
import '../../domain/entities/resource.dart';
import '../providers/resources_providers.dart';
import '../utils/resource_format.dart';
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
      // Never the error red: video is not a failure state.
      return c.ink700;
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

/// Type tag text for [resource]: PDFs are called out instead of "DOC".
String resourceLabelFor(Resource resource) => resourceIsPdf(resource)
    ? 'resources.type_label.pdf'.tr()
    : resourceTypeLabel(resource.resourceType);

/// Two-column grid used by the library and its loading skeleton.
const SliverGridDelegate resourceGridDelegate =
    SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 200,
  mainAxisSpacing: 12,
  crossAxisSpacing: 12,
  childAspectRatio: 0.72,
);

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
    final sizeStr = formatResourceFileSize(resource.fileSize);
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
        : fetched?.value;
    final videoThumb = videoPreviewUrl(resource.externalUrl);

    return Semantics(
      button: true,
      label: '${resource.title}, ${resourceLabelFor(resource)}',
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
                          fontSize: SacFontSize.bodyMedium,
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
                            fontSize: SacFontSize.labelSmall,
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
                label: resourceLabelFor(resource),
                icon: icon,
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
            fontSize: SacFontSize.bodyMedium,
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

    return _TypeGlyph(color: color, icon: icon);
  }
}

class _TypeGlyph extends StatelessWidget {
  final Color color;
  final List<List<dynamic>> icon;

  const _TypeGlyph({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(child: HugeIcon(icon: icon, size: 36, color: color));
  }
}

/// Icon + label on a translucent dark pill. The fixed dark tint keeps white
/// text readable over any cover; the blur is limited to the pill's own bounds.
class _TypeBadge extends StatelessWidget {
  final String label;
  final List<List<dynamic>> icon;

  const _TypeBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
          color: AppColors.ink900.withValues(alpha: 0.66),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: icon, size: 12, color: Colors.white),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: SacFontSize.caption,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
