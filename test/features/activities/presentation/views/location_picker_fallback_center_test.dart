import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sacdia_app/core/constants/maps_constants.dart';
import 'package:sacdia_app/features/activities/presentation/views/location_picker_view.dart';

void main() {
  const fallback = LatLng(MapsConstants.defaultLat, MapsConstants.defaultLong);

  test('uses the club section coordinates when available', () {
    expect(
      locationPickerFallbackCenter(clubLat: 17.0732, clubLong: -96.7266),
      const LatLng(17.0732, -96.7266),
    );
  });

  test('falls back to the default center without usable coordinates', () {
    expect(locationPickerFallbackCenter(), fallback);
    expect(locationPickerFallbackCenter(clubLat: 17.07), fallback);
    expect(locationPickerFallbackCenter(clubLat: 0, clubLong: 0), fallback);
    expect(locationPickerFallbackCenter(clubLat: 120, clubLong: 10), fallback);
  });
}
