import 'package:equatable/equatable.dart';

import 'material_entrega.dart';

/// Configuración bancaria y de entrega del módulo de materiales.
///
/// Singleton en el backend (fila id=1). El app solo la lee — no la escribe.
class MaterialConfig extends Equatable {
  final String? bankName;
  final String? bankAccountClabe;
  final String? accountHolder;

  /// Costo de envío por defecto en centavos (MXN).
  final int envioCentavosDefault;

  final String? pickupAddress;

  /// Opciones de entrega habilitadas (lista de [MaterialEntrega]).
  final List<MaterialEntrega> deliveryOptions;

  final DateTime updatedAt;

  const MaterialConfig({
    this.bankName,
    this.bankAccountClabe,
    this.accountHolder,
    required this.envioCentavosDefault,
    this.pickupAddress,
    required this.deliveryOptions,
    required this.updatedAt,
  });

  bool get hasPickup => deliveryOptions.contains(MaterialEntrega.recoger);
  bool get hasShipping => deliveryOptions.contains(MaterialEntrega.envio);

  @override
  List<Object?> get props => [
        bankName,
        bankAccountClabe,
        accountHolder,
        envioCentavosDefault,
        pickupAddress,
        deliveryOptions,
        updatedAt,
      ];
}
