import '../../../camporee_orders/data/models/camporee_order_product_model.dart';
import '../../../camporee_orders/domain/entities/camporee_order_offering.dart';
import '../../../camporee_orders/domain/entities/camporee_order_product.dart';
import '../../domain/entities/supervision_camporee_orders.dart';

Map<String, dynamic>? _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : null;

String? _str(Object? v) {
  if (v == null || v is Map || v is List) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

String _text(Object? v) => _str(v) ?? '';

int? _int(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.toInt();
  return null;
}

bool _active(Object? v) => v != false && v != 'false' && v != 0;

/// Parsers for the union camporee merchandise and supply configuration.
/// Order payloads reuse the camporee_orders models after normalizing types.
class SupervisionCamporeeOrdersModel {
  const SupervisionCamporeeOrdersModel._();

  static SupervisionSupplyUom uomFromWire(Object? v) {
    switch (v) {
      case 'KG':
        return SupervisionSupplyUom.kg;
      case 'L':
        return SupervisionSupplyUom.l;
      case 'BAG':
        return SupervisionSupplyUom.bag;
      case 'UNIT':
        return SupervisionSupplyUom.unit;
      default:
        return SupervisionSupplyUom.unknown;
    }
  }

  /// Null for [SupervisionSupplyUom.unknown] (never sent).
  static String? uomToWire(SupervisionSupplyUom uom) {
    switch (uom) {
      case SupervisionSupplyUom.kg:
        return 'KG';
      case SupervisionSupplyUom.l:
        return 'L';
      case SupervisionSupplyUom.bag:
        return 'BAG';
      case SupervisionSupplyUom.unit:
        return 'UNIT';
      case SupervisionSupplyUom.unknown:
        return null;
    }
  }

  // ---- Merchandise orders ----

  /// Product map with int-like fields coerced and malformed options dropped.
  static Map<String, dynamic>? _sanitizeProduct(Object? raw) {
    final json = _map(raw);
    if (json == null || _str(json['camporee_order_product_id']) == null) {
      return null;
    }
    final options = json['options'] is List
        ? (json['options'] as List)
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .where((o) => _str(o['camporee_order_product_option_id']) != null)
            .map((o) => {...o, 'sort_order': _int(o['sort_order']) ?? 0})
            .toList()
        : <Map<String, dynamic>>[];
    return {...json, 'options': options};
  }

  /// Library products (`GET /camporee-order-products`); rows without id are
  /// dropped.
  static List<CamporeeOrderProduct> parseProducts(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map(_sanitizeProduct)
        .whereType<Map<String, dynamic>>()
        .map((m) => CamporeeOrderProductModel.fromJson(m).toEntity())
        .toList();
  }

  static Map<String, dynamic> _settingsMap(Object? raw) =>
      _map(raw) ?? <String, dynamic>{};

  /// Settings from a payload `{orders_enabled, orders_opens_at, ...}`.
  static CamporeeOrderSettings parseSettings(Object? raw) {
    final json = _settingsMap(raw);
    return CamporeeOrderOfferingsCatalogModel.fromJson({'settings': json})
        .toEntity()
        .settings;
  }

  /// Offerings catalog `{settings, items}`; offerings without ids are dropped.
  static CamporeeOrderOfferingsCatalog parseOfferingsCatalog(Object? raw) {
    final json = _map(raw) ?? <String, dynamic>{};
    final items = json['items'] is List ? json['items'] as List : const [];
    final clean = <Map<String, dynamic>>[];
    for (final item in items) {
      final m = _map(item);
      if (m == null || _str(m['camporee_order_offering_id']) == null) continue;
      final product = _sanitizeProduct(m['product']);
      if (product == null) continue;
      clean.add({
        ...m,
        'price_centavos': _int(m['price_centavos']) ?? 0,
        'sort_order': _int(m['sort_order']) ?? 0,
        'product': product,
      });
    }
    return CamporeeOrderOfferingsCatalogModel.fromJson({
      'settings': _settingsMap(json['settings']),
      'items': clean,
    }).toEntity();
  }

  // ---- Supplies ----

  static SupervisionSupplySlot? tryParseSlot(Object? raw) {
    final json = _map(raw);
    final id = json == null ? null : _str(json['slot_id']);
    if (json == null || id == null) return null;
    return SupervisionSupplySlot(
      id: id,
      label: _text(json['label']),
      deliverTime: _text(json['deliver_time']),
      sortOrder: _int(json['sort_order']) ?? 0,
      active: _active(json['active']),
    );
  }

  static SupervisionSupplyProduct? tryParseProduct(Object? raw) {
    final json = _map(raw);
    final id = json == null ? null : _str(json['product_id']);
    if (json == null || id == null) return null;
    return SupervisionSupplyProduct(
      id: id,
      name: _text(json['name']),
      uom: uomFromWire(json['uom']),
      unitCostCentavos: _int(json['unit_cost_centavos']) ?? 0,
      active: _active(json['active']),
    );
  }

  /// Null only when the body is not an object.
  static SupervisionSupplyCatalog? tryParseCatalog(Object? raw) {
    final json = _map(raw);
    if (json == null) return null;
    List<T> rows<T>(Object? v, T? Function(Object?) parse) =>
        v is List ? v.map(parse).whereType<T>().toList() : <T>[];
    return SupervisionSupplyCatalog(
      cutoffTime: _text(json['supply_edit_cutoff_local_time']),
      timezone: _text(json['timezone']),
      slots: rows(json['slots'], tryParseSlot),
      products: rows(json['products'], tryParseProduct),
    );
  }
}
