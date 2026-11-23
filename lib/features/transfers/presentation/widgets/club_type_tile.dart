import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/club_type.dart';
import '../../../../core/theme/sac_colors.dart';

/// Square tile with the logo of a club type (or a neutral icon).
class ClubTypeTile extends StatelessWidget {
  const ClubTypeTile({super.key, this.clubTypeName, this.initials});

  final String? clubTypeName;

  /// Shown instead of a logo (for clubs listed by name).
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final initials = this.initials;
    final logo = initials == null ? clubLogoAssetFromName(clubTypeName) : null;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
      ),
      child: logo != null
          ? Image.asset(logo, width: 28, fit: BoxFit.contain)
          : initials != null
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    fontWeight: FontWeight.w700,
                    color: c.textSecondary,
                  ),
                )
              : HugeIcon(
                  icon: HugeIcons.strokeRoundedUserGroup,
                  size: 20,
                  color: c.textSecondary,
                ),
    );
  }
}
