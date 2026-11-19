import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/activity.dart';
import 'activity_map_options_sheet.dart';

/// Builds the map of [ActivityMapCard]. Tests replace it: a real GoogleMap
/// needs a platform view.
typedef ActivityMapBuilder = Widget Function(
  BuildContext context,
  LatLng center,
  String place,
);

/// Whether the detail shows the map card: in-person or hybrid activities
/// that have a place or coordinates (virtual ones never do).
bool activityHasMapCard(Activity activity) =>
    activity.platform != 1 &&
    (activity.hasLocation || activity.activityPlace.trim().isNotEmpty);

/// Rounded, bordered map under the header of the activity detail with an
/// "Open in maps" pill; a tap opens the maps chooser. Under it, one line with
/// the place.
class ActivityMapCard extends StatelessWidget {
  const ActivityMapCard({super.key, required this.activity, this.mapBuilder});

  final Activity activity;
  final ActivityMapBuilder? mapBuilder;

  static const double mapHeight = 160;

  static Widget _defaultMap(BuildContext context, LatLng center, String place) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(target: center, zoom: 15),
      markers: {
        Marker(
          markerId: const MarkerId('activity-location'),
          position: center,
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
      liteModeEnabled: defaultTargetPlatform == TargetPlatform.android,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final place = activity.activityPlace.trim();
    final hasLocation = activity.hasLocation;

    final Widget map;
    if (hasLocation) {
      final center = LatLng(activity.lat!, activity.longitude!);
      map = (mapBuilder ?? _defaultMap)(context, center, place);
    } else {
      map = ColoredBox(
        color: c.surfaceVariant,
        child: Center(
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedLocation01,
            size: 32,
            color: c.textTertiary,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            label: 'activities.detail.map_semantics'
                .tr(namedArgs: {'place': place}),
            excludeSemantics: true,
            onTap: () => showActivityMapOptions(context, activity),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: c.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                child: SizedBox(
                  height: mapHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RepaintBoundary(child: IgnorePointer(child: map)),
                      Positioned.fill(
                        child: SacInkWell(
                          onTap: () =>
                              showActivityMapOptions(context, activity),
                          pressedScale: 1,
                          child: const SizedBox.expand(),
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: IgnorePointer(child: _OpenPill(color: c)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (place.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
              child: Text(
                place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.bodyMedium,
                  height: 1.35,
                  color: c.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _OpenPill extends StatelessWidget {
  const _OpenPill({required this.color});

  final SacColors color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
        border: Border.all(color: color.border),
        boxShadow: [
          BoxShadow(
              color: color.shadow, blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedMaps,
            size: 14,
            color: SacAccent.of(context).color,
          ),
          const SizedBox(width: 6),
          Text(
            'activities.widgets.open_in_maps'.tr(),
            style: TextStyle(
              fontSize: SacFontSize.bodySmall,
              fontWeight: FontWeight.w600,
              color: color.text,
            ),
          ),
        ],
      ),
    );
  }
}
