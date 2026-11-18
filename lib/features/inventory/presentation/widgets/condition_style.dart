import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/inventory_item.dart';

/// Icon and colors of each [ItemCondition], from the semantic tokens so they
/// follow dark mode. The icon always travels with the label: color is never
/// the only signal.
extension ItemConditionStyle on ItemCondition {
  HugeIconData get icon => switch (this) {
        ItemCondition.bueno => HugeIcons.strokeRoundedCheckmarkCircle02,
        ItemCondition.regular => HugeIcons.strokeRoundedAlert02,
        ItemCondition.malo => HugeIcons.strokeRoundedCancelCircle,
      };

  /// Solid tone for the dot next to the label.
  Color dotColor(SacColors c) => switch (this) {
        ItemCondition.bueno => c.success,
        ItemCondition.regular => c.warning,
        ItemCondition.malo => c.error,
      };

  Color container(SacColors c) => switch (this) {
        ItemCondition.bueno => c.successContainer,
        ItemCondition.regular => c.warningContainer,
        ItemCondition.malo => c.errorContainer,
      };

  /// Text and icon color on [container]; readable in light and dark.
  Color onContainer(SacColors c) => switch (this) {
        ItemCondition.bueno => c.onSuccessContainer,
        ItemCondition.regular => c.onWarningContainer,
        ItemCondition.malo => c.onErrorContainer,
      };
}
