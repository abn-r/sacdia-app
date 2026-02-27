/// Utilidades para el manejo y traducción de roles del sistema
class RoleUtils {
  const RoleUtils._();

  /// Mapa de roles en inglés (clave del sistema) a su nombre en español
  static const Map<String, String> _roleNames = {
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
  };

  /// Retorna el nombre en español del rol dado.
  ///
  /// Si el rol no está mapeado, retorna el valor original con la primera
  /// letra en mayúscula como fallback.
  static String translate(String? role) {
    if (role == null || role.isEmpty) return '';
    return _roleNames[role.toLowerCase()] ?? _capitalize(role);
  }

  /// Traduce una lista de roles y los une con coma.
  static String translateList(List<String> roles) {
    return roles.map(translate).join(', ');
  }

  /// Capitaliza la primera letra de un string como fallback.
  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).replaceAll('_', ' ');
  }
}
