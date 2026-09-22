import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:sacdia_app/core/config/cache_config.dart';

/// Profile photo on disk.
///
/// Uses [SacProfileCacheManager] and [stableImageCacheKey], so a new signature
/// on the same object does not download again and does not evict badge images.
/// A replaced photo has a new object name and misses this cache.
class SacProfileImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  const SacProfileImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.memCacheWidth,
    this.memCacheHeight,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: stableImageCacheKey(imageUrl),
      cacheManager: SacProfileCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      memCacheWidth: memCacheWidth,
      memCacheHeight: memCacheHeight,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}

/// [ImageProvider] for [CircleAvatar.backgroundImage] and similar slots.
ImageProvider sacProfileImageProvider(String url) {
  return CachedNetworkImageProvider(
    url,
    cacheKey: stableImageCacheKey(url),
    cacheManager: SacProfileCacheManager.instance,
  );
}
