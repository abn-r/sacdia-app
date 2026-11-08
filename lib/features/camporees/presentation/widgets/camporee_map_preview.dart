import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../domain/entities/camporee.dart';

/// Static map with the camporee pin. Gestures are off: tapping the row
/// around it opens the map apps.
class CamporeeMapPreview extends StatelessWidget {
  final Camporee camporee;

  const CamporeeMapPreview({super.key, required this.camporee});

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
