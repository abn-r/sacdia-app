import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/sac_badge.dart';
import '../../domain/entities/inventory_item.dart';

/// Badge que indica el estado de conservación del ítem.
///
/// Usa [SacBadge] (tokens semánticos, seguro en modo oscuro) con un icono
/// para no depender solo del color.
class ConditionBadge extends StatelessWidget {
  final ItemCondition condition;
  final bool compact;

  const ConditionBadge({
    super.key,
    required this.condition,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final label = compact ? condition.shortLabel : condition.label;

    switch (condition) {
      case ItemCondition.bueno:
        return SacBadge.success(
          label: label,
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        );
      case ItemCondition.regular:
        return SacBadge.warning(
          label: label,
          icon: HugeIcons.strokeRoundedAlert02,
        );
      case ItemCondition.malo:
        return SacBadge.error(
          label: label,
          icon: HugeIcons.strokeRoundedCancelCircle,
        );
    }
  }
}
