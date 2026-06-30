import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/camporee.dart';

Future<void> showCamporeeMapOptions(
  BuildContext context,
  Camporee camporee,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _CamporeeMapOptionsSheet(camporee: camporee),
  );
}

class _CamporeeMapOptionsSheet extends StatelessWidget {
  final Camporee camporee;

  const _CamporeeMapOptionsSheet({required this.camporee});

  bool get _hasCoordinates =>
      camporee.lat != null && camporee.longitude != null;

  String get _coordinateQuery => '${camporee.lat},${camporee.longitude}';

  String get _placeQuery {
    final place = camporee.place.trim();
    return place.isEmpty ? _coordinateQuery : place;
  }

  Uri get _googleMapsAppUri {
    final query = Uri.encodeComponent(
      _hasCoordinates ? _coordinateQuery : _placeQuery,
    );
    if (_hasCoordinates) {
      return Uri.parse(
        'comgooglemaps://?q=$query&center=$_coordinateQuery&zoom=15',
      );
    }
    return Uri.parse('comgooglemaps://?q=$query');
  }

  Uri get _googleMapsWebUri => Uri.https(
        'www.google.com',
        '/maps/search/',
        {
          'api': '1',
          'query': _hasCoordinates ? _coordinateQuery : _placeQuery,
        },
      );

  Uri get _appleMapsUri => Uri.https(
        'maps.apple.com',
        '/',
        {
          if (_hasCoordinates) 'll': _coordinateQuery,
          'q': _placeQuery,
        },
      );

  Uri get _wazeAppUri => Uri.parse(
        'waze://?ll=$_coordinateQuery&navigate=yes',
      );

  Uri get _wazeWebUri => Uri.https(
        'waze.com',
        '/ul',
        {
          'll': _coordinateQuery,
          'navigate': 'yes',
        },
      );

  Future<void> _launch(
    BuildContext context, {
    required Uri primaryUri,
    Uri? fallbackUri,
  }) async {
    var launched = false;
    try {
      if (await canLaunchUrl(primaryUri)) {
        launched = await launchUrl(
          primaryUri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched && fallbackUri != null) {
        launched = await launchUrl(
          fallbackUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      if (fallbackUri != null && !launched) {
        try {
          launched = await launchUrl(
            fallbackUri,
            mode: LaunchMode.externalApplication,
          );
        } catch (_) {
          launched = false;
        }
      }
    }

    if (!context.mounted) return;
    if (launched) {
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('camporees.detail.map_open_error'.tr()),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final platform = Theme.of(context).platform;
    final showAppleMaps =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: sac.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: sac.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'camporees.detail.open_location_title'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (camporee.place.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              camporee.place,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: sac.textSecondary,
                    height: 1.35,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 14),
          _MapOptionTile(
            icon: HugeIcons.strokeRoundedMaps,
            label: 'Google Maps',
            onTap: () => _launch(
              context,
              primaryUri: _googleMapsAppUri,
              fallbackUri: _googleMapsWebUri,
            ),
          ),
          if (showAppleMaps)
            _MapOptionTile(
              icon: HugeIcons.strokeRoundedLocation01,
              label: 'Maps',
              onTap: () => _launch(context, primaryUri: _appleMapsUri),
            ),
          if (_hasCoordinates)
            _MapOptionTile(
              icon: HugeIcons.strokeRoundedRoute01,
              label: 'Waze',
              onTap: () => _launch(
                context,
                primaryUri: _wazeAppUri,
                fallbackUri: _wazeWebUri,
              ),
            ),
        ],
      ),
    );
  }
}

class _MapOptionTile extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final VoidCallback onTap;

  const _MapOptionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: icon,
                  size: 20,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: sac.text,
                      ),
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 16,
                color: sac.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
