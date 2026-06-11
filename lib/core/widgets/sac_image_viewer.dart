import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

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
