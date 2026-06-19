import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Visor de imagenes fullscreen con zoom (pinch-to-zoom).
///
/// Se abre como ruta fullscreenDialog para cubrir toda la pantalla
/// incluyendo el bottom navigation bar del shell.
class SacImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? title;

  const SacImageViewer({
    super.key,
    required String imageUrl,
    this.title,
  })  : imageUrls = const [],
        initialIndex = 0,
        _singleImageUrl = imageUrl;

  const SacImageViewer.gallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.title,
  }) : _singleImageUrl = null;

  final String? _singleImageUrl;

  List<String> get _effectiveImageUrls =>
      imageUrls.isNotEmpty ? imageUrls : [_singleImageUrl!];

  static void show(
    BuildContext context, {
    required String imageUrl,
    String? title,
    List<String>? imageUrls,
    int initialIndex = 0,
  }) {
    final effectiveUrls =
        imageUrls == null || imageUrls.isEmpty ? [imageUrl] : imageUrls;
    final safeInitialIndex = effectiveUrls.isEmpty
        ? 0
        : initialIndex.clamp(0, effectiveUrls.length - 1);

    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SacImageViewer.gallery(
          imageUrls: effectiveUrls,
          initialIndex: safeInitialIndex,
          title: title,
        ),
      ),
    );
  }

  @override
  State<SacImageViewer> createState() => _SacImageViewerState();
}

class _SacImageViewerState extends State<SacImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  final GlobalKey _saveButtonKey = GlobalKey();
  bool _isSharing = false;

  List<String> get _imageUrls => widget._effectiveImageUrls;
  bool get _hasMultipleImages => _imageUrls.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, _imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: _buildTitle(),
          leading: IconButton(
            icon: const HugeIcon(icon: HugeIcons.strokeRoundedCancel01),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              key: _saveButtonKey,
              tooltip: 'common.save'.tr(),
              onPressed: _isSharing ? null : _shareCurrentImage,
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const HugeIcon(
                      icon: HugeIcons.strokeRoundedDownload01,
                      color: Colors.white,
                    ),
            ),
          ],
        ),
        body: Stack(
          children: [
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: _imageUrls.length,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              builder: (context, index) => PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(_imageUrls[index]),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 3,
                errorBuilder: (context, error, stackTrace) =>
                    _buildErrorState(),
              ),
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
            if (_hasMultipleImages) _buildPageIndicator(),
          ],
        ),
      ),
    );
  }

  Future<void> _shareCurrentImage() async {
    if (_isSharing || _imageUrls.isEmpty) return;

    setState(() => _isSharing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final imageUrl = _imageUrls[_currentIndex];
      final fileName = _safeFileNameFromUrl(
        imageUrl,
        fallback:
            'sacdia_evidence_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');

      await Dio().download(imageUrl, file.path);

      if (!mounted) return;
      await Share.shareXFiles(
        [
          XFile(
            file.path,
            name: fileName,
            mimeType: _imageMimeType(fileName),
          ),
        ],
        sharePositionOrigin: _sharePositionOriginForContext(
          _saveButtonKey.currentContext ?? context,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(tr('core.image_viewer.error_load')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Widget? _buildTitle() {
    final title = widget.title;
    final counter =
        _hasMultipleImages ? '${_currentIndex + 1}/${_imageUrls.length}' : null;

    final text = [
      if (title != null && title.isNotEmpty) title,
      if (counter != null) counter,
    ].join(' · ');

    if (text.isEmpty) return null;

    return Text(
      text,
      style: const TextStyle(fontSize: 14, color: Colors.white70),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildPageIndicator() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 28 + MediaQuery.paddingOf(context).bottom,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_imageUrls.length, (index) {
          final selected = index == _currentIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: selected ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.white38,
              borderRadius: BorderRadius.circular(999),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedImageDelete01,
            size: 48,
            color: Colors.white38,
          ),
          const SizedBox(height: 8),
          Text(
            tr('core.image_viewer.error_load'),
            style: const TextStyle(color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

Rect? _sharePositionOriginForContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final size = renderObject.size;
  if (size.isEmpty) return null;
  return renderObject.localToGlobal(Offset.zero) & size;
}

String? _lastNonEmptySegment(List<String>? segments) {
  if (segments == null) return null;
  for (final segment in segments.reversed) {
    if (segment.trim().isNotEmpty) return segment;
  }
  return null;
}

String _safeFileNameFromUrl(String url, {required String fallback}) {
  final uri = Uri.tryParse(url);
  final rawSegment = _lastNonEmptySegment(uri?.pathSegments);
  final decoded =
      rawSegment == null ? fallback : Uri.decodeComponent(rawSegment);
  final sanitized = decoded.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  if (sanitized.isEmpty || !sanitized.contains('.')) return fallback;
  return sanitized;
}

String? _imageMimeType(String fileName) {
  final lower = fileName.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic')) return 'image/heic';
  if (lower.endsWith('.heif')) return 'image/heif';
  return null;
}
