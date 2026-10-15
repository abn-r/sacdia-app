import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/activities/data/models/activity_model.dart';
import 'package:sacdia_app/features/activities/domain/entities/activity.dart';

void main() {
  test('parses attendee_profiles from the activity detail payload', () {
    final model = ActivityModel.fromJson({
      'activity_id': 1,
      'name': 'Campamento',
      'activity_place': 'Parque',
      'attendees': ['u1', 'u2'],
      'attendee_profiles': [
        {
          'user_id': 'u1',
          'name': 'Juan',
          'paternal_last_name': 'Pérez',
          'maternal_last_name': null,
          'user_image': 'https://signed.example/u1.jpg',
        },
        {'name': 'sin id'},
      ],
    });

    expect(model.toEntity().attendeeProfiles, const [
      ActivityAttendee(
        userId: 'u1',
        name: 'Juan',
        paternalLastName: 'Pérez',
        imageUrl: 'https://signed.example/u1.jpg',
      ),
    ]);
  });

  test('older payloads without attendee_profiles yield an empty list', () {
    final model = ActivityModel.fromJson({
      'activity_id': 1,
      'name': 'Campamento',
      'activity_place': 'Parque',
      'attendees': ['u1'],
    });

    expect(model.toEntity().attendeeProfiles, isEmpty);
  });
}
