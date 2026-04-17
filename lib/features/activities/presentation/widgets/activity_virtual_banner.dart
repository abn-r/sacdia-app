import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

import '../../domain/entities/activity.dart';

/// Compact 140px banner for virtual activities (platform == 1).
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
        _buildContent(context),
        if (activity.isPast)
          Container(color: Colors.black.withValues(alpha: 0.35)),
        // "Finalizada" state is signaled via the countdown pill in
        // ActivityInfoStrip below the hero.
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    final hasImage = activity.image != null && activity.image!.isNotEmpty;
    if (hasImage) {
      return CachedNetworkImage(
        imageUrl: activity.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
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
            AppColors.sacBlue,
            AppColors.sacBlue.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedComputerVideoCall,
                  size: 24,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Actividad Virtual',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
