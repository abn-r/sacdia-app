/// Construye el payload de PATCH /users/:userId para la pantalla de edición
/// de perfil.
///
/// Importante: el backend valida `phone` con regex cuando la propiedad existe.
/// Por eso `phone: ''` NO equivale a "sin teléfono"; debe omitirse.
Map<String, dynamic> buildEditProfilePayload({
  required String name,
  required String paternalSurname,
  required String maternalSurname,
  required String phone,
  required String address,
  required String? genderApiKey,
  required DateTime? birthdate,
  required bool baptized,
  required DateTime? baptismDate,
}) {
  final payload = <String, dynamic>{
    'name': name.trim(),
    'paternal_last_name': paternalSurname.trim(),
    'maternal_last_name': maternalSurname.trim(),
  };

  final trimmedPhone = phone.trim();
  if (trimmedPhone.isNotEmpty) {
    payload['phone'] = trimmedPhone;
  }

  final trimmedAddress = address.trim();
  if (trimmedAddress.isNotEmpty) {
    payload['address'] = trimmedAddress;
  }

  if (genderApiKey != null) {
    payload['gender'] = genderApiKey;
  }

  if (birthdate != null) {
    payload['birthday'] = birthdate.toUtc().toIso8601String();
  }

  payload['baptism'] = baptized;

  if (baptized && baptismDate != null) {
    payload['baptism_date'] = baptismDate.toUtc().toIso8601String();
  }

  return payload;
}
