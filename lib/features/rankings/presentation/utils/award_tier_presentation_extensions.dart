import 'package:flutter/material.dart';

import '../../domain/entities/award_tier.dart';

extension AwardTierPresentationX on AwardTier {
  /// Color representativo del tier — consistente con achievementTierColor.
  Color get color {
    switch (this) {
      case AwardTier.bronze:
        return const Color(0xFFCD7F32);
      case AwardTier.silver:
        return const Color(0xFFC0C0C0);
      case AwardTier.gold:
        return const Color(0xFFFFD700);
      case AwardTier.diamond:
        return const Color(0xFFB9F2FF);
      case AwardTier.unknown:
        return const Color(0xFF303030); // AppColors.darkBorder
    }
  }
}
