import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/activity.dart';

/// Tap-able address row for presencial / híbrido activities.
///
/// - Tap → opens location in Google Maps (coords or place name fallback).
/// - Long-press → copies the address to clipboard.
class ActivityLocationRow extends StatelessWidget {
  final Activity activity;
  const ActivityLocationRow({super.key, required this.activity});

  Future<void> _openInMaps() async {
    final lat = activity.lat;
    final lng = activity.longitude;
    final place = Uri.encodeComponent(activity.activityPlace);

    final Uri uri;
    if (lat != null && lng != null) {
      uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    } else {
      uri = Uri.parse('https://maps.google.com/?q=$place');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyAddress(BuildContext context) {
    Clipboard.setData(ClipboardData(text: activity.activityPlace));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Dirección copiada'),
        backgroundColor: AppColors.secondaryDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    if (activity.activityPlace.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openInMaps,
        onLongPress: () => _copyAddress(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sac.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sac.borderLight, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedLocation01,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'UBICACIÓN',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: sac.textTertiary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      activity.activityPlace,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: sac.text,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Abrir',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12,
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
