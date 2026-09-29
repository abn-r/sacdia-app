import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

import '../../domain/entities/activity.dart';

/// Banner for virtual activities (platform == 1). Height comes from the detail view.
///
/// Renders the activity image when available, else a gradient with a video
/// icon. Includes the same "past activity" dimming + Finalizada badge used
/// by [ActivityHeroSection] so visual treatment is consistent across
/// platforms.
class ActivityVirtualBanner extends StatelessWidget {
  final Activity activity;
  const ActivityVirtualBanner({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildContent(),
        if (activity.isPast)
          Container(color: Colors.black.withValues(alpha: 0.35)),
        // "Finalizada" state is signaled via the countdown pill in
        // ActivityInfoStrip below the hero.
      ],
    );
  }

  Widget _buildContent() {
    final hasImage = activity.image != null && activity.image!.isNotEmpty;
    if (hasImage) {
      return CachedNetworkImage(
        imageUrl: activity.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: 1080,
        memCacheHeight: 210,
        placeholder: (_, __) => _gradient(),
        errorWidget: (_, __, ___) => _gradient(),
      );
    }
    return _gradient();
  }

  Widget _gradient() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.info,
            AppColors.info.withValues(alpha: 0.6),
          ],
        ),
      ),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedComputerVideoCall,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'activities.widgets.virtual_fallback'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
