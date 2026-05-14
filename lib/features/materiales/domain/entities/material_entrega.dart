/// Modalidad de entrega para una orden de materiales.
enum MaterialEntrega {
  recoger,
  envio,
}

/// Extensiones de utilidad para [MaterialEntrega].
extension MaterialEntregaX on MaterialEntrega {
  static MaterialEntrega fromString(String value) {
    switch (value) {
      case 'envio':
        return MaterialEntrega.envio;
      default:
        return MaterialEntrega.recoger;
    }
  }

  String toApiString() {
    switch (this) {
      case MaterialEntrega.recoger:
        return 'recoger';
      case MaterialEntrega.envio:
        return 'envio';
    }
  }
}
