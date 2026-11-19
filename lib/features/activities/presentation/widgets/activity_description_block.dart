import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

import 'activity_detail_row.dart';

/// "DESCRIPTION" eyebrow plus the full text, wrapped over as many lines as it
/// needs: members must be able to read everything the activity asks of them.
class ActivityDescriptionBlock extends StatelessWidget {
  const ActivityDescriptionBlock({super.key, required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActivityEyebrow('activities.detail.section_description'.tr()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            description,
            key: const ValueKey('activity-description'),
            softWrap: true,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              height: 1.55,
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
