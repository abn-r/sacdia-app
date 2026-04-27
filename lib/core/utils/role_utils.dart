import 'package:easy_localization/easy_localization.dart';

/// Utilidades para el manejo y traducción de roles del sistema
class RoleUtils {
  const RoleUtils._();

  /// Conjunto de claves de rol conocidas por el sistema.
  static const _knownRoles = {
    'super_admin',
    'admin',
    'assistant_admin',
    'coordinator',
    'pastor',
    'user',
    'director',
    'deputy_director',
    'secretary',
    'treasurer',
    'counselor',
    'instructor',
    'member',
    'secretary_treasurer',
  };

  /// Retorna true si el valor de género indica sexo femenino.
  ///
  /// El backend almacena el género como `'Femenino'` o `'Masculino'`
  /// (enum PostgreSQL). Se acepta también la variante en minúsculas.
  static bool _isFeminine(String? gender) {
    if (gender == null) return false;
    final normalized = gender.trim().toLowerCase();
    return normalized == 'femenino' || normalized == 'f';
  }

  /// Retorna el nombre localizado del rol dado, con concordancia de género.
  ///
  /// [gender] debe ser el valor proveniente del campo `gender` del usuario
  /// cuyo rol se está mostrando — no el del usuario logueado.
  /// Valores reconocidos: `'Femenino'`, `'Masculino'` (los que devuelve la API).
  ///
  /// Si [gender] es null o no es femenino, se usa la forma masculina.
  /// Si el rol no está mapeado, retorna el valor original capitalizado como
  /// fallback (sin distinción de género).
  static String translate(String? role, {String? gender}) {
    if (role == null || role.isEmpty) return '';
    final key = role.toLowerCase();
    if (!_knownRoles.contains(key)) return _capitalize(role);
    final genderSuffix = _isFeminine(gender) ? 'feminine' : 'masculine';
    return tr('roles.$key.$genderSuffix');
  }

  /// Traduce una lista de roles y los une con coma.
  ///
  /// [gender] se aplica a todos los roles de la lista.
  static String translateList(List<String> roles, {String? gender}) {
    return roles.map((r) => translate(r, gender: gender)).join(', ');
  }

  /// Capitaliza la primera letra de un string como fallback.
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }
}
