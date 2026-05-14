/// Estado de disponibilidad de una línea de orden.
enum MaterialDisponibilidad {
  pendiente,
  disponible,
  parcial,
  agotado,
}

/// Extensiones de utilidad para [MaterialDisponibilidad].
extension MaterialDisponibilidadX on MaterialDisponibilidad {
  static MaterialDisponibilidad fromString(String value) {
    switch (value) {
      case 'disponible':
        return MaterialDisponibilidad.disponible;
      case 'parcial':
        return MaterialDisponibilidad.parcial;
      case 'agotado':
        return MaterialDisponibilidad.agotado;
      default:
        return MaterialDisponibilidad.pendiente;
    }
  }

  String toApiString() {
    switch (this) {
      case MaterialDisponibilidad.pendiente:
        return 'pendiente';
      case MaterialDisponibilidad.disponible:
        return 'disponible';
      case MaterialDisponibilidad.parcial:
        return 'parcial';
      case MaterialDisponibilidad.agotado:
        return 'agotado';
    }
  }
}
