import 'dart:io' as io;
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sacdia_app/core/config/cache_config.dart';
import 'package:sacdia_app/core/utils/network_image_url.dart';

/// Network image that supports raster (png/jpg/webp) and SVG URLs.
///
/// Raster URLs use [CachedNetworkImage] (the app-wide [SacCacheManager]).
/// SVG URLs are stored in that same disk cache and painted with
/// [SvgPicture.file]. The cache key ignores the query string, so a signed
/// badge URL still hits after the signature rotates.
class SacNetworkImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  /// Test hook. Production leaves this null and reads [SacCacheManager].
  final Future<Uint8List> Function(String url, String cacheKey)? loadSvgBytes;

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
    this.loadSvgBytes,
  });

  @override
  Widget build(BuildContext context) {
    if (isSvgNetworkUrl(imageUrl)) {
      return _CachedSvgPicture(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        loadSvgBytes: loadSvgBytes,
      );
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheKey: stableImageCacheKey(imageUrl),
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

class _CachedSvgPicture extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final Future<Uint8List> Function(String url, String cacheKey)? loadSvgBytes;

  const _CachedSvgPicture({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fit,
    required this.placeholder,
    required this.errorWidget,
    required this.loadSvgBytes,
  });

  @override
  State<_CachedSvgPicture> createState() => _CachedSvgPictureState();
}

class _CachedSvgPictureState extends State<_CachedSvgPicture> {
  Stream<FileResponse>? _stream;
  Future<Uint8List>? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _CachedSvgPicture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.loadSvgBytes != widget.loadSvgBytes) {
      _load();
    }
  }

  void _load() {
    final key = stableImageCacheKey(widget.imageUrl);
    final loader = widget.loadSvgBytes;
    if (loader != null) {
      _stream = null;
      _bytes = loader(widget.imageUrl, key);
      return;
    }
    _bytes = null;
    _stream = SacCacheManager.instance.getFileStream(
      widget.imageUrl,
      key: key,
    );
  }

  Widget _waiting(BuildContext context) {
    final placeholder = widget.placeholder;
    if (placeholder != null) return placeholder(context, widget.imageUrl);
    return SizedBox(width: widget.width, height: widget.height);
  }

  Widget _failed(BuildContext context, Object error) {
    final errorWidget = widget.errorWidget;
    if (errorWidget != null) {
      return errorWidget(context, widget.imageUrl, error);
    }
    return SizedBox(width: widget.width, height: widget.height);
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return FutureBuilder<Uint8List>(
        future: bytes,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _failed(context, snapshot.error!);
          }
          final data = snapshot.data;
          if (data == null) return _waiting(context);
          return SvgPicture.memory(
            data,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
          );
        },
      );
    }

    return StreamBuilder<FileResponse>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError && snapshot.data is! FileInfo) {
          return _failed(context, snapshot.error!);
        }
        final data = snapshot.data;
        if (data is! FileInfo) return _waiting(context);
        return SvgPicture.file(
          io.File(data.file.path),
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          errorBuilder: widget.errorWidget == null
              ? null
              : (context, error, stackTrace) =>
                  widget.errorWidget!(context, widget.imageUrl, error),
        );
      },
    );
  }
}
