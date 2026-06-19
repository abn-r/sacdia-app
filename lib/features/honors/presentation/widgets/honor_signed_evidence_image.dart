import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/honors_providers.dart';

final Set<String> _scheduledEvidenceUrlRefreshes = <String>{};

void _scheduleEvidenceUrlRefresh(WidgetRef ref, String imageUrl) {
  final trimmedUrl = imageUrl.trim();
  if (trimmedUrl.isEmpty) return;

  // Signed R2 URLs change after every refresh. Keep a small in-session guard so
  // a broken URL triggers one automatic refetch, not an infinite error loop.
  if (_scheduledEvidenceUrlRefreshes.length > 200) {
    _scheduledEvidenceUrlRefreshes.clear();
  }
  if (!_scheduledEvidenceUrlRefreshes.add(trimmedUrl)) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.invalidate(userHonorsProvider);
  });
}

class HonorSignedEvidenceImage extends ConsumerStatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int? memCacheWidth;
  final int? memCacheHeight;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;

  const HonorSignedEvidenceImage({
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
  ConsumerState<HonorSignedEvidenceImage> createState() =>
      _HonorSignedEvidenceImageState();
}

class _HonorSignedEvidenceImageState
    extends ConsumerState<HonorSignedEvidenceImage> {
  bool _refreshRequested = false;

  @override
  void didUpdateWidget(HonorSignedEvidenceImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _refreshRequested = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      memCacheHeight: widget.memCacheHeight,
      placeholder: widget.placeholder,
      errorWidget: (context, url, error) {
        if (!_refreshRequested) {
          _refreshRequested = true;
          _scheduleEvidenceUrlRefresh(ref, widget.imageUrl);
          return widget.placeholder?.call(context, url) ??
              _RefreshingEvidencePlaceholder(
                width: widget.width,
                height: widget.height,
              );
        }

        return widget.errorWidget?.call(context, url, error) ??
            const SizedBox.shrink();
      },
    );
  }
}

class _RefreshingEvidencePlaceholder extends StatelessWidget {
  final double? width;
  final double? height;

  const _RefreshingEvidencePlaceholder({
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
