import '../../domain/entities/camporee_order_offering.dart';
import '../../domain/entities/camporee_order_product.dart';

class CamporeeOrderProductOptionModel {
  final String optionId;
  final String label;
  final int sortOrder;
  final bool active;

  const CamporeeOrderProductOptionModel({
    required this.optionId,
    required this.label,
    required this.sortOrder,
    required this.active,
  });

  factory CamporeeOrderProductOptionModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderProductOptionModel(
      optionId: json['camporee_order_product_option_id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
    );
  }

  CamporeeOrderProductOption toEntity() => CamporeeOrderProductOption(
        optionId: optionId,
        label: label,
        sortOrder: sortOrder,
        active: active,
      );
}

class CamporeeOrderProductModel {
  final String productId;
  final String ownerScope;
  final String title;
  final String? description;
  final String sizeScheme;
  final bool active;
  final List<CamporeeOrderProductOptionModel> options;

  const CamporeeOrderProductModel({
    required this.productId,
    required this.ownerScope,
    required this.title,
    required this.sizeScheme,
    required this.active,
    this.description,
    this.options = const [],
  });

  factory CamporeeOrderProductModel.fromJson(Map<String, dynamic> json) {
    return CamporeeOrderProductModel(
      productId: json['camporee_order_product_id']?.toString() ?? '',
      ownerScope: json['owner_scope']?.toString() ?? 'LOCAL_FIELD',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString(),
      sizeScheme: json['size_scheme']?.toString() ?? 'NONE',
      active: json['active'] != false,
      options: (json['options'] as List<dynamic>? ?? [])
          .map(
            (e) => CamporeeOrderProductOptionModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  CamporeeOrderProduct toEntity() => CamporeeOrderProduct(
        productId: productId,
        ownerScope: CamporeeOrderOwnerScopeApi.fromApi(ownerScope),
        title: title,
        description: description,
        sizeScheme: CamporeeOrderSizeSchemeApi.fromApi(sizeScheme),
        active: active,
        options: options.map((o) => o.toEntity()).toList(),
      );
}

class CamporeeOrderOfferingModel {
  final String offeringId;
  final int priceCentavos;
  final bool active;
  final int sortOrder;
  final CamporeeOrderProductModel product;

  const CamporeeOrderOfferingModel({
    required this.offeringId,
    required this.priceCentavos,
    required this.active,
    required this.sortOrder,
    required this.product,
  });

  factory CamporeeOrderOfferingModel.fromJson(Map<String, dynamic> json) {
    final productJson = json['product'];
    return CamporeeOrderOfferingModel(
      offeringId: json['camporee_order_offering_id']?.toString() ?? '',
      priceCentavos: (json['price_centavos'] as num?)?.toInt() ?? 0,
      active: json['active'] != false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      product: CamporeeOrderProductModel.fromJson(
        productJson is Map<String, dynamic> ? productJson : const {},
      ),
    );
  }

  CamporeeOrderOffering toEntity() => CamporeeOrderOffering(
        offeringId: offeringId,
        priceCentavos: priceCentavos,
        active: active,
        sortOrder: sortOrder,
        product: product.toEntity(),
      );
}

class CamporeeOrderOfferingsCatalogModel {
  final bool ordersEnabled;
  final DateTime? ordersOpensAt;
  final DateTime? ordersDeadline;
  final List<CamporeeOrderOfferingModel> items;

  const CamporeeOrderOfferingsCatalogModel({
    required this.ordersEnabled,
    this.ordersOpensAt,
    this.ordersDeadline,
    this.items = const [],
  });

  factory CamporeeOrderOfferingsCatalogModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final settings = json['settings'];
    final settingsMap =
        settings is Map<String, dynamic> ? settings : <String, dynamic>{};
    return CamporeeOrderOfferingsCatalogModel(
      ordersEnabled: settingsMap['orders_enabled'] == true,
      ordersOpensAt:
          DateTime.tryParse(settingsMap['orders_opens_at']?.toString() ?? ''),
      ordersDeadline:
          DateTime.tryParse(settingsMap['orders_deadline']?.toString() ?? ''),
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (e) => CamporeeOrderOfferingModel.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  CamporeeOrderOfferingsCatalog toEntity() => CamporeeOrderOfferingsCatalog(
        settings: CamporeeOrderSettings(
          ordersEnabled: ordersEnabled,
          ordersOpensAt: ordersOpensAt,
          ordersDeadline: ordersDeadline,
        ),
        items: items.map((i) => i.toEntity()).toList(),
      );
}

typedef CamporeeOrderOfferingsResultModel = CamporeeOrderOfferingsCatalogModel;
