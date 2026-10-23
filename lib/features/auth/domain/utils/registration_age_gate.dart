/// Edad mínima por defecto para tener cuenta propia (FP-65).
///
/// El backend decide con la política del país (`minor_self_login_min_age`); el
/// formulario de registro no conoce el país, así que filtra con el valor por
/// defecto del servidor y deja que el 422 `AUTH_REGISTRATION_AGE_BELOW_MINIMUM`
/// cubra el resto.
const int kDefaultMinSelfLoginAge = 13;

/// Mayoría de edad por defecto (FP3-31): quien se registra con menos queda en
/// modo supervisado. El país puede cambiarla; el servidor decide. Solo sirve
/// para avisar en el formulario, nunca para bloquear ni permitir nada.
const int kDefaultAgeOfMajority = 18;

/// Código de negocio del backend cuando la edad no alcanza el mínimo.
const String kRegistrationAgeBelowMinimumCode =
    'AUTH_REGISTRATION_AGE_BELOW_MINIMUM';

/// Años cumplidos de [birthday] en [today] (calendario local, sin horas).
int ageOn(DateTime birthday, DateTime today) {
  var age = today.year - birthday.year;
  final hadBirthday = today.month > birthday.month ||
      (today.month == birthday.month && today.day >= birthday.day);
  if (!hadBirthday) age--;
  return age;
}

/// `true` si [birthday] no alcanza [minAge] en [today] (o está en el futuro).
bool isBelowRegistrationMinAge(
  DateTime birthday,
  DateTime today, {
  int minAge = kDefaultMinSelfLoginAge,
}) =>
    ageOn(birthday, today) < minAge;

/// `true` si [birthday] alcanza el mínimo para tener cuenta pero no la mayoría
/// de edad por defecto: la cuenta nacerá supervisada (aviso en el registro).
bool isSupervisedRegistrationAge(
  DateTime birthday,
  DateTime today, {
  int minAge = kDefaultMinSelfLoginAge,
  int majority = kDefaultAgeOfMajority,
}) {
  final age = ageOn(birthday, today);
  return age >= minAge && age < majority;
}

/// `YYYY-MM-DD` tal como lo espera el backend.
String formatBirthdayIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Error de `signUp` cuando el servidor rechaza el registro por edad.
///
/// Se publica como valor de error del `AsyncValue` del `AuthNotifier` para que
/// el formulario muestre la misma pantalla de bloqueo que el filtro local.
class RegistrationAgeBelowMinimum implements Exception {
  const RegistrationAgeBelowMinimum();

  @override
  String toString() => kRegistrationAgeBelowMinimumCode;
}
