/// Estado de un comprobante de pago.
enum MaterialComprobanteStatus {
  pendiente,
  aprobado,
  rechazado,
}

/// Extensiones de utilidad para [MaterialComprobanteStatus].
extension MaterialComprobanteStatusX on MaterialComprobanteStatus {
  static MaterialComprobanteStatus fromString(String value) {
    switch (value) {
      case 'aprobado':
        return MaterialComprobanteStatus.aprobado;
      case 'rechazado':
        return MaterialComprobanteStatus.rechazado;
      default:
        return MaterialComprobanteStatus.pendiente;
    }
  }

  String toApiString() {
    switch (this) {
      case MaterialComprobanteStatus.pendiente:
        return 'pendiente';
      case MaterialComprobanteStatus.aprobado:
        return 'aprobado';
      case MaterialComprobanteStatus.rechazado:
        return 'rechazado';
    }
  }
}
