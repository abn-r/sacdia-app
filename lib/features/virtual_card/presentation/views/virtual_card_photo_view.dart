import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class VirtualCardPhotoView extends StatelessWidget {
  const VirtualCardPhotoView({
    super.key,
    required this.title,
    this.photoUrl,
  });

  final String title;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> imageProvider =
        photoUrl == null || photoUrl!.isEmpty
            ? const AssetImage('assets/img/LogoSACDIA.png')
            : CachedNetworkImageProvider(photoUrl!);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title),
      ),
      body: Center(
        child: PhotoView(
          imageProvider: imageProvider,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}
