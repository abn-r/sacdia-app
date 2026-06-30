import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import '../../domain/entities/camporee.dart';
import 'camporee_map_options_sheet.dart';

class CamporeeLocationCard extends StatelessWidget {
  final Camporee camporee;

  const CamporeeLocationCard({super.key, required this.camporee});

  bool get _hasCoordinates =>
      camporee.lat != null && camporee.longitude != null;

  void _copyAddress(BuildContext context) {
    Clipboard.setData(ClipboardData(text: camporee.place));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('camporees.detail.address_copied'.tr()),
        backgroundColor: AppColors.secondaryDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (camporee.place.trim().isEmpty) return const SizedBox.shrink();

    final c = context.sac;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => showCamporeeMapOptions(context, camporee),
        onLongPress: () => _copyAddress(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedLocation01,
                        size: 17,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'camporees.detail.location_title'.tr(),
                          style: TextStyle(
                            color: c.textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          camporee.place,
                          style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'camporees.detail.open_in_maps'.tr(),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedArrowRight01,
                              size: 12,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = math.min(constraints.maxWidth, 310.0);
                  return Center(
                    child: SizedBox(
                      width: width,
                      height: width * 9 / 16,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _hasCoordinates
                            ? _CamporeeMapPreview(camporee: camporee)
                            : const _LocationPreviewFallback(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CamporeeMapPreview extends StatelessWidget {
  final Camporee camporee;

  const _CamporeeMapPreview({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final center = LatLng(camporee.lat!, camporee.longitude!);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 15),
      markers: {
        Marker(
          markerId: const MarkerId('camporee-location'),
          position: center,
          infoWindow: InfoWindow(title: camporee.place),
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
    );
  }
}

class _LocationPreviewFallback extends StatelessWidget {
  const _LocationPreviewFallback();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      color: AppColors.secondary.withValues(alpha: 0.10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedMaps,
            size: 26,
            color: AppColors.secondary,
          ),
          const SizedBox(height: 8),
          Text(
            'camporees.detail.location_no_coordinates'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
