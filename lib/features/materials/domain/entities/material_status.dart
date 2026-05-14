/// Estado de una orden de materiales.
enum MaterialStatus {
  enRevision,
  aprobada,
  pagada,
  entregada,
  cancelada,
}

/// Extensiones de utilidad para [MaterialStatus].
extension MaterialStatusX on MaterialStatus {
  /// Convierte el string que devuelve la API al enum correspondiente.
  static MaterialStatus fromString(String value) {
    switch (value) {
      case 'en_revision':
        return MaterialStatus.enRevision;
      case 'aprobada':
        return MaterialStatus.aprobada;
      case 'pagada':
        return MaterialStatus.pagada;
      case 'entregada':
        return MaterialStatus.entregada;
      case 'cancelada':
        return MaterialStatus.cancelada;
      default:
        return MaterialStatus.enRevision;
    }
  }

  /// Devuelve la representación string que espera la API.
  String toApiString() {
    switch (this) {
      case MaterialStatus.enRevision:
        return 'en_revision';
      case MaterialStatus.aprobada:
        return 'aprobada';
      case MaterialStatus.pagada:
        return 'pagada';
      case MaterialStatus.entregada:
        return 'entregada';
      case MaterialStatus.cancelada:
        return 'cancelada';
    }
  }

  bool get isTerminal =>
      this == MaterialStatus.entregada || this == MaterialStatus.cancelada;
}
