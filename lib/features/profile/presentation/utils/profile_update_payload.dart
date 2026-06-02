/// Builds the payload accepted by `PATCH /api/v1/users/:userId` for profile edits.
///
/// Keep this aligned with the backend `UpdateUserDto`: do not include legacy
/// fields that are not part of the effective `users` model.
Map<String, dynamic> buildProfileUpdatePayload({
  required String name,
  required String paternalLastName,
  required String maternalLastName,
  required bool baptism,
  String? gender,
  DateTime? birthday,
  DateTime? baptismDate,
}) {
  final data = <String, dynamic>{
    'name': name.trim(),
    'paternal_last_name': paternalLastName.trim(),
    'maternal_last_name': maternalLastName.trim(),
    'baptism': baptism,
  };

  if (gender != null) data['gender'] = gender;
  if (birthday != null) data['birthday'] = birthday.toUtc().toIso8601String();
  if (baptism && baptismDate != null) {
    data['baptism_date'] = baptismDate.toUtc().toIso8601String();
  }

  return data;
}
