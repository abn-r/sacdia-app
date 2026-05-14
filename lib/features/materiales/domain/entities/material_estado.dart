/// Estado de una orden de materiales.
enum MaterialEstado {
  enRevision,
  aprobada,
  pagada,
  entregada,
  cancelada,
}

/// Extensiones de utilidad para [MaterialEstado].
extension MaterialEstadoX on MaterialEstado {
  /// Convierte el string que devuelve la API al enum correspondiente.
  static MaterialEstado fromString(String value) {
    switch (value) {
      case 'en_revision':
        return MaterialEstado.enRevision;
      case 'aprobada':
        return MaterialEstado.aprobada;
      case 'pagada':
        return MaterialEstado.pagada;
      case 'entregada':
        return MaterialEstado.entregada;
      case 'cancelada':
        return MaterialEstado.cancelada;
      default:
        return MaterialEstado.enRevision;
    }
  }

  /// Devuelve la representación string que espera la API.
  String toApiString() {
    switch (this) {
      case MaterialEstado.enRevision:
        return 'en_revision';
      case MaterialEstado.aprobada:
        return 'aprobada';
      case MaterialEstado.pagada:
        return 'pagada';
      case MaterialEstado.entregada:
        return 'entregada';
      case MaterialEstado.cancelada:
        return 'cancelada';
    }
  }

  bool get isTerminal =>
      this == MaterialEstado.entregada || this == MaterialEstado.cancelada;
}
