import 'package:equatable/equatable.dart';

/// Dueño territorial del producto en la biblioteca.
enum CamporeeOrderOwnerScope { division, union, localField }

extension CamporeeOrderOwnerScopeApi on CamporeeOrderOwnerScope {
  String get apiValue {
    switch (this) {
      case CamporeeOrderOwnerScope.division:
        return 'DIVISION';
      case CamporeeOrderOwnerScope.union:
        return 'UNION';
      case CamporeeOrderOwnerScope.localField:
        return 'LOCAL_FIELD';
    }
  }

  static CamporeeOrderOwnerScope fromApi(String value) {
    switch (value) {
      case 'UNION':
        return CamporeeOrderOwnerScope.union;
      case 'LOCAL_FIELD':
        return CamporeeOrderOwnerScope.localField;
      case 'DIVISION':
      default:
        return CamporeeOrderOwnerScope.division;
    }
  }
}

/// Eje único de talla. NONE = pines, libros, sin `option_id`.
enum CamporeeOrderSizeScheme { letter, numeric, none }

extension CamporeeOrderSizeSchemeApi on CamporeeOrderSizeScheme {
  String get apiValue {
    switch (this) {
      case CamporeeOrderSizeScheme.letter:
        return 'LETTER';
      case CamporeeOrderSizeScheme.numeric:
        return 'NUMERIC';
      case CamporeeOrderSizeScheme.none:
        return 'NONE';
    }
  }

  static CamporeeOrderSizeScheme fromApi(String value) {
    switch (value) {
      case 'LETTER':
        return CamporeeOrderSizeScheme.letter;
      case 'NUMERIC':
        return CamporeeOrderSizeScheme.numeric;
      case 'NONE':
      default:
        return CamporeeOrderSizeScheme.none;
    }
  }

  bool get requiresOption => this != CamporeeOrderSizeScheme.none;
}

/// Opción de talla de un producto de la biblioteca.
class CamporeeOrderProductOption extends Equatable {
  final String optionId;
  final String productId;
  final String label;
  final int sortOrder;
  final bool active;

  const CamporeeOrderProductOption({
    required this.optionId,
    required this.productId,
    required this.label,
    required this.sortOrder,
    required this.active,
  });

  @override
  List<Object?> get props => [optionId, label, sortOrder, active];
}

/// Producto de la biblioteca territorial (no es MaterialProduct).
class CamporeeOrderProduct extends Equatable {
  final String productId;
  final String title;
  final String? description;
  final CamporeeOrderSizeScheme sizeScheme;
  final CamporeeOrderOwnerScope ownerScope;
  final int? ownerDivisionId;
  final int? ownerUnionId;
  final int? ownerLocalFieldId;
  final int? clubTypeId;
  final bool active;
  final List<CamporeeOrderProductOption> options;

  const CamporeeOrderProduct({
    required this.productId,
    required this.title,
    required this.sizeScheme,
    required this.ownerScope,
    required this.active,
    this.description,
    this.ownerDivisionId,
    this.ownerUnionId,
    this.ownerLocalFieldId,
    this.clubTypeId,
    this.options = const [],
  });

  @override
  List<Object?> get props => [productId, sizeScheme, active];
}
