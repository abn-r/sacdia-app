import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/club/data/models/club_info_model.dart';

void main() {
  group('ClubInfoModel location', () {
    test('reads the [lat, long] coordinates array returned by GET /clubs/:id',
        () {
      final club = ClubInfoModel.fromJson(const {
        'club_id': 1,
        'name': 'ACV',
        'lat': null,
        'long': null,
        'coordinates': [19.192313841413668, -96.13046280557836],
      });

      expect(club.lat, closeTo(19.1923, 0.0001));
      expect(club.long, closeTo(-96.1304, 0.0001));
    });

    test('prefers explicit lat/long over coordinates', () {
      final club = ClubInfoModel.fromJson(const {
        'club_id': 1,
        'name': 'ACV',
        'lat': 18.5,
        'long': -95.5,
        'coordinates': [19.19, -96.13],
      });

      expect(club.lat, 18.5);
      expect(club.long, -95.5);
    });

    test('has no location when the club has none', () {
      final club = ClubInfoModel.fromJson(const {'club_id': 1, 'name': 'ACV'});

      expect(club.lat, isNull);
      expect(club.long, isNull);
    });
  });
}
