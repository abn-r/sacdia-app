import 'package:flutter/material.dart';

import '../../domain/entities/award_tier.dart';
import '../../../../core/theme/app_colors.dart';
import '../theme/ranking_tokens.dart';

extension AwardTierPresentationX on AwardTier {
  /// Color representativo del tier — consistente con achievementTierColor.
  Color get color {
    switch (this) {
      case AwardTier.bronze:
        return RankingTokens.awardBronze;
      case AwardTier.silver:
        return RankingTokens.awardSilver;
      case AwardTier.gold:
        return RankingTokens.awardGold;
      case AwardTier.diamond:
        return RankingTokens.awardDiamond;
      case AwardTier.unknown:
        return AppColors.darkBorder;
    }
  }
}
