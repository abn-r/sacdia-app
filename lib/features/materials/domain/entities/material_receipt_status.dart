/// Estado de un comprobante de pago.
enum MaterialReceiptStatus {
  pendiente,
  aprobado,
  rechazado,
}

/// Extensiones de utilidad para [MaterialReceiptStatus].
extension MaterialReceiptStatusX on MaterialReceiptStatus {
  static MaterialReceiptStatus fromString(String value) {
    switch (value) {
      case 'aprobado':
        return MaterialReceiptStatus.aprobado;
      case 'rechazado':
        return MaterialReceiptStatus.rechazado;
      default:
        return MaterialReceiptStatus.pendiente;
    }
  }

  String toApiString() {
    switch (this) {
      case MaterialReceiptStatus.pendiente:
        return 'pendiente';
      case MaterialReceiptStatus.aprobado:
        return 'aprobado';
      case MaterialReceiptStatus.rechazado:
        return 'rechazado';
    }
  }
}
