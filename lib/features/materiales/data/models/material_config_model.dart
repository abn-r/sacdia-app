import '../../domain/entities/material_config.dart';
import '../../domain/entities/material_entrega.dart';

/// Modelo de datos para [MaterialConfig].
///
/// Mapea la respuesta JSON de GET /materiales/configuracion.
class MaterialConfigModel extends MaterialConfig {
  const MaterialConfigModel({
    super.bankName,
    super.bankAccountClabe,
    super.accountHolder,
    required super.envioCentavosDefault,
    super.pickupAddress,
    required super.deliveryOptions,
    required super.updatedAt,
  });

  factory MaterialConfigModel.fromJson(Map<String, dynamic> json) {
    // delivery_options: el backend devuelve un array de strings
    // ej. ["recoger", "envio"] o un JSON array
    final rawOptions = json['delivery_options'] ?? json['deliveryOptions'];
    List<MaterialEntrega> deliveryOptions = [];
    if (rawOptions is List) {
      deliveryOptions = rawOptions
          .map((o) => MaterialEntregaX.fromString(o.toString()))
          .toList();
    }

    return MaterialConfigModel(
      bankName:
          (json['bank_name'] ?? json['bankName'])?.toString(),
      bankAccountClabe:
          (json['bank_account_clabe'] ?? json['bankAccountClabe'])?.toString(),
      accountHolder:
          (json['account_holder'] ?? json['accountHolder'])?.toString(),
      envioCentavosDefault:
          (json['envio_centavos_default'] ?? json['envioCentavosDefault'] ?? 0)
              as int,
      pickupAddress:
          (json['pickup_address'] ?? json['pickupAddress'])?.toString(),
      deliveryOptions: deliveryOptions,
      updatedAt: DateTime.tryParse(
              (json['updated_at'] ?? json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (bankName != null) 'bank_name': bankName,
      if (bankAccountClabe != null) 'bank_account_clabe': bankAccountClabe,
      if (accountHolder != null) 'account_holder': accountHolder,
      'envio_centavos_default': envioCentavosDefault,
      if (pickupAddress != null) 'pickup_address': pickupAddress,
      'delivery_options':
          deliveryOptions.map((o) => o.toApiString()).toList(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MaterialConfig toEntity() => MaterialConfig(
        bankName: bankName,
        bankAccountClabe: bankAccountClabe,
        accountHolder: accountHolder,
        envioCentavosDefault: envioCentavosDefault,
        pickupAddress: pickupAddress,
        deliveryOptions: deliveryOptions,
        updatedAt: updatedAt,
      );
}
