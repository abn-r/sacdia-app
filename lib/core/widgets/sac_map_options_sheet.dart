import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens Google Maps / Apple Maps / Waze for a place or lat/lng pair.
Future<void> showSacMapOptions(
  BuildContext context, {
  required String title,
  required String errorMessage,
  String? place,
  double? lat,
  double? lng,
}) {
  return showSacSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SacMapOptionsSheet(
      title: title,
      errorMessage: errorMessage,
      place: place,
      lat: lat,
      lng: lng,
    ),
  );
}

class _SacMapOptionsSheet extends StatelessWidget {
  const _SacMapOptionsSheet({
    required this.title,
    required this.errorMessage,
    this.place,
    this.lat,
    this.lng,
  });

  final String title;
  final String errorMessage;
  final String? place;
  final double? lat;
  final double? lng;

  bool get _hasCoordinates => lat != null && lng != null;

  String get _coordinateQuery => '$lat,$lng';

  String get _placeQuery {
    final trimmed = place?.trim() ?? '';
    return trimmed.isEmpty ? _coordinateQuery : trimmed;
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

    SacSnackBar.show(context, errorMessage, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final platform = Theme.of(context).platform;
    final showAppleMaps =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    final placeLabel = place?.trim() ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: sac.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SacSheetHeader(
            title: title,
            subtitle: placeLabel.isEmpty ? null : placeLabel,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
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
