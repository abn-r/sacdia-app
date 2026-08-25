import 'package:equatable/equatable.dart';

/// Eje único de talla. Género = productos distintos, no un segundo eje.
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

  bool get requiresOption => this != CamporeeOrderSizeScheme.none;

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
}

enum CamporeeOrderOwnerScope { division, union, localField }

extension CamporeeOrderOwnerScopeApi on CamporeeOrderOwnerScope {
  static CamporeeOrderOwnerScope fromApi(String value) {
    switch (value) {
      case 'DIVISION':
        return CamporeeOrderOwnerScope.division;
      case 'UNION':
        return CamporeeOrderOwnerScope.union;
      case 'LOCAL_FIELD':
      default:
        return CamporeeOrderOwnerScope.localField;
    }
  }
}

class CamporeeOrderProductOption extends Equatable {
  final String optionId;
  final String label;
  final int sortOrder;
  final bool active;

  const CamporeeOrderProductOption({
    required this.optionId,
    required this.label,
    required this.sortOrder,
    required this.active,
  });

  @override
  List<Object?> get props => [optionId, label];
}

/// Producto de la biblioteca territorial (dueño Division|Union|LF).
class CamporeeOrderProduct extends Equatable {
  final String productId;
  final CamporeeOrderOwnerScope ownerScope;
  final String title;
  final String? description;
  final CamporeeOrderSizeScheme sizeScheme;
  final bool active;
  final List<CamporeeOrderProductOption> options;

  const CamporeeOrderProduct({
    required this.productId,
    required this.ownerScope,
    required this.title,
    required this.sizeScheme,
    required this.active,
    this.description,
    this.options = const [],
  });

  bool get requiresOption => sizeScheme.requiresOption;

  @override
  List<Object?> get props => [productId, sizeScheme, title];
}
