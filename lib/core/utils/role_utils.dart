/// Utilidades para el manejo y traducción de roles del sistema
class RoleUtils {
  const RoleUtils._();

  /// Mapa de roles en inglés (clave del sistema) a su nombre en español
  /// en forma masculina (género por defecto).
  static const Map<String, String> _roleNamesMasculine = {
    'super_admin': 'Súper administrador',
    'admin': 'Administrador',
    'assistant_admin': 'Administrador asistente',
    'coordinator': 'Coordinador',
    'pastor': 'Pastor',
    'user': 'Usuario',
    'director': 'Director',
    'deputy_director': 'Subdirector',
    'secretary': 'Secretario',
    'treasurer': 'Tesorero',
    'counselor': 'Consejero',
    'instructor': 'Instructor',
    'member': 'Miembro',
    'secretary_treasurer': 'Secretario-Tesorero',
  };

  /// Mapa de roles en inglés (clave del sistema) a su nombre en español
  /// en forma femenina.
  static const Map<String, String> _roleNamesFeminine = {
    'super_admin': 'Súper administradora',
    'admin': 'Administradora',
    'assistant_admin': 'Administradora asistente',
    'coordinator': 'Coordinadora',
    'pastor': 'Pastora',
    'user': 'Usuaria',
    'director': 'Directora',
    'deputy_director': 'Subdirectora',
    'secretary': 'Secretaria',
    'treasurer': 'Tesorera',
    'counselor': 'Consejera',
    'instructor': 'Instructora',
    'member': 'Miembro',
    'secretary_treasurer': 'Secretaria-Tesorera',
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

  /// Retorna el nombre en español del rol dado, con concordancia de género.
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
    final map =
        _isFeminine(gender) ? _roleNamesFeminine : _roleNamesMasculine;
    return map[key] ?? _capitalize(role);
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
