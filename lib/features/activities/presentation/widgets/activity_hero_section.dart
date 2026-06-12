import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/activity.dart';
import 'activity_map_options_sheet.dart';

/// Hero content for the activity detail screen.
///
/// Designed to be used inside a [FlexibleSpaceBar] background so it fills
/// edge-to-edge behind the AppBar (no border radius, full bleed).
///
/// - platform 0 (Presencial): google_maps_flutter with location pin, or fallback card.
/// - platform 1 (Virtual): full-width image (16:9), or solid icon card.
/// - platform 2 (Híbrido): image with a floating "Join Meet" chip overlay.
///
/// The platform badge is NOT rendered here — it lives in the title badge row
/// below the hero (see ActivityDetailView._buildTitleSection).
class ActivityHeroSection extends StatelessWidget {
  final Activity activity;

  const ActivityHeroSection({super.key, required this.activity});

  // ── map (platform 0) ───────────────────────────────────────────────────────

  Widget _buildMapHero(BuildContext context) {
    if (activity.hasLocation) {
      final center = LatLng(activity.lat!, activity.longitude!);

      return GoogleMap(
        initialCameraPosition: CameraPosition(target: center, zoom: 15),
        markers: {
          Marker(
            markerId: const MarkerId('activity-location'),
            position: center,
            infoWindow: InfoWindow(title: activity.activityPlace),
            onTap: () => showActivityMapOptions(context, activity),
          ),
        },
        zoomControlsEnabled: false,
        scrollGesturesEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        zoomGesturesEnabled: false,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        compassEnabled: false,
        // liteModeEnabled solo funciona en Android; en iOS deja el mapa en blanco.
      );
    }

    return _buildLocationFallback(context);
  }

  Widget _buildLocationFallback(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedLocation01,
            color: AppColors.secondary,
            size: 26,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          activity.activityPlace,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.secondaryDark,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (activity.hasLocation) ...[
          const SizedBox(height: 4),
          Text(
            '${activity.lat!.toStringAsFixed(4)}, ${activity.longitude!.toStringAsFixed(4)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryDark.withValues(alpha: 0.7),
                ),
          ),
        ],
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => showActivityMapOptions(context, activity),
          icon: const HugeIcon(icon: HugeIcons.strokeRoundedMaps, size: 16),
          label: Text('activities.widgets.open_in_maps'.tr()),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );

    return Container(
      color: AppColors.secondaryLight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: content,
            ),
          ),
        ),
      ),
    );
  }

  // ── image hero (platform 1 & 2) ───────────────────────────────────────────

  Widget _buildImageHero(BuildContext context) {
    final hasImage = activity.image != null && activity.image!.isNotEmpty;

    Widget imageContent;
    if (hasImage) {
      imageContent = CachedNetworkImage(
        imageUrl: activity.image!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(
          color: context.sac.surfaceVariant,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => _buildVideoFallback(context),
      );
    } else {
      imageContent = _buildVideoFallback(context);
    }

    // platform == 2: add "Join Meet" chip overlay
    if (activity.platform == 2 && activity.linkMeet != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          imageContent,
          Positioned(
            bottom: 72,
            right: 16,
            child: _JoinMeetChip(url: activity.linkMeet!),
          ),
        ],
      );
    }

    return imageContent;
  }

  Widget _buildVideoFallback(BuildContext context) {
    return Container(
      color: AppColors.info.withValues(alpha: 0.12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedComputerVideoCall,
              size: 28,
              color: AppColors.info,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'activities.widgets.virtual_fallback'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.info,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    Widget hero;
    switch (activity.platform) {
      case 1:
      case 2:
        hero = _buildImageHero(context);
        break;
      default:
        hero = _buildMapHero(context);
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        hero,
        // Past activity dimming overlay
        if (activity.isPast)
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        // Bottom gradient for readability
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 80,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Note: "Finalizada" state is signaled via the countdown pill in
        // ActivityInfoStrip below the hero — no badge here to avoid status-bar
        // collision and redundancy.
      ],
    );
  }
}

// ── _JoinMeetChip ─────────────────────────────────────────────────────────────

class _JoinMeetChip extends StatelessWidget {
  final String url;

  const _JoinMeetChip({required this.url});

  Future<void> _launch() async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _launch,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.info,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedComputerVideoCall,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Text(
              'activities.widgets.join_button'.tr(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
