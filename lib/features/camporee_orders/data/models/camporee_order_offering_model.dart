import '../../domain/entities/camporee_order_offering.dart';
import 'camporee_order_product_model.dart';

/// Modelo de settings de pedidos del camporee.
class CamporeeOrderSettingsModel {
  final bool ordersEnabled;
  final DateTime? ordersOpensAt;
  final DateTime? ordersDeadline;

  const CamporeeOrderSettingsModel({
    required this.ordersEnabled,
    this.ordersOpensAt,
    this.ordersDeadline,
  });

  factory CamporeeOrderSettingsModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderSettingsModel(
      ordersEnabled: json['orders_enabled'] == true,
      ordersOpensAt:
          DateTime.tryParse(json['orders_opens_at']?.toString() ?? ''),
      ordersDeadline:
          DateTime.tryParse(json['orders_deadline']?.toString() ?? ''),
    );
  }

  CamporeeOrderSettings toEntity() => CamporeeOrderSettings(
        ordersEnabled: ordersEnabled,
        ordersOpensAt: ordersOpensAt,
        ordersDeadline: ordersDeadline,
      );
}

/// Modelo de oferta (producto × camporee × precio).
class CamporeeOrderOfferingModel {
  final String offeringId;
  final int? localCamporeeId;
  final int? unionCamporeeId;
  final String productId;
  final int priceCentavos;
  final bool active;
  final int sortOrder;
  final CamporeeOrderProductModel product;

  const CamporeeOrderOfferingModel({
    required this.offeringId,
    required this.productId,
    required this.priceCentavos,
    required this.active,
    required this.sortOrder,
    required this.product,
    this.localCamporeeId,
    this.unionCamporeeId,
  });

  factory CamporeeOrderOfferingModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'] as Map<String, dynamic>? ?? const {};
    return CamporeeOrderOfferingModel(
      offeringId: json['camporee_order_offering_id']?.toString() ?? '',
      localCamporeeId: (json['local_camporee_id'] as num?)?.toInt(),
      unionCamporeeId: (json['union_camporee_id'] as num?)?.toInt(),
      productId: json['product_id']?.toString() ??
          productJson['camporee_order_product_id']?.toString() ??
          '',
      priceCentavos: (json['price_centavos'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      product: CamporeeOrderProductModel.fromJson(productJson),
    );
  }

  CamporeeOrderOffering toEntity() => CamporeeOrderOffering(
        offeringId: offeringId,
        localCamporeeId: localCamporeeId,
        unionCamporeeId: unionCamporeeId,
        productId: productId,
        priceCentavos: priceCentavos,
        active: active,
        sortOrder: sortOrder,
        product: product.toEntity(),
      );
}

/// Envelope de GET order-offerings.
class CamporeeOrderOfferingsResultModel {
  final CamporeeOrderSettingsModel settings;
  final List<CamporeeOrderOfferingModel> items;

  const CamporeeOrderOfferingsResultModel({
    required this.settings,
    this.items = const [],
  });

  factory CamporeeOrderOfferingsResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return CamporeeOrderOfferingsResultModel(
      settings: CamporeeOrderSettingsModel.fromJson(
        json['settings'] as Map<String, dynamic>? ?? const {},
      ),
      items: (json['items'] as List<dynamic>? ?? [])
          .map((e) =>
              CamporeeOrderOfferingModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  CamporeeOrderOfferingsResult toEntity() => CamporeeOrderOfferingsResult(
        settings: settings.toEntity(),
        items: items.map((i) => i.toEntity()).toList(),
      );
}
