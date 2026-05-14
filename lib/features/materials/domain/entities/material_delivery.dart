/// Modalidad de entrega para una orden de materiales.
enum MaterialDelivery {
  recoger,
  envio,
}

/// Extensiones de utilidad para [MaterialDelivery].
extension MaterialDeliveryX on MaterialDelivery {
  static MaterialDelivery fromString(String value) {
    switch (value) {
      case 'envio':
        return MaterialDelivery.envio;
      default:
        return MaterialDelivery.recoger;
    }
  }

  String toApiString() {
    switch (this) {
      case MaterialDelivery.recoger:
        return 'recoger';
      case MaterialDelivery.envio:
        return 'envio';
    }
  }
}
