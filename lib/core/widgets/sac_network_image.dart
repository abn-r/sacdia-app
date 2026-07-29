import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sacdia_app/core/utils/network_image_url.dart';

/// Network image that supports raster (png/jpg/webp) and SVG URLs.
///
/// Raster URLs use [CachedNetworkImage]. SVG URLs use [SvgPicture.network]
/// (detected via [isSvgNetworkUrl]).
class SacNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  const SacNetworkImage({
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
    if (isSvgNetworkUrl(imageUrl)) {
      return SvgPicture.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholderBuilder: placeholder == null
            ? null
            : (context) => placeholder!(context, imageUrl),
        errorBuilder: errorWidget == null
            ? null
            : (context, error, stackTrace) =>
                errorWidget!(context, imageUrl, error),
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
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
