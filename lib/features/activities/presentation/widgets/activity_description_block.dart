import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import 'activity_detail_row.dart';

/// "DESCRIPTION" eyebrow plus the text as a plain block, collapsed to four
/// lines with a "See more" toggle when it is long.
class ActivityDescriptionBlock extends StatefulWidget {
  const ActivityDescriptionBlock({super.key, required this.description});

  final String description;

  static const int collapseThreshold = 200;

  @override
  State<ActivityDescriptionBlock> createState() =>
      _ActivityDescriptionBlockState();
}

class _ActivityDescriptionBlockState extends State<ActivityDescriptionBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final style = TextStyle(
      fontSize: SacFontSize.bodyMedium,
      height: 1.55,
      color: c.textSecondary,
    );
    final isLong =
        widget.description.length > ActivityDescriptionBlock.collapseThreshold;
    final reduceMotion = SacMotion.reduceMotionOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActivityEyebrow('activities.detail.section_description'.tr()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedSize(
            duration: reduceMotion ? Duration.zero : SacMotion.standard,
            curve: SacMotion.easeOut,
            alignment: Alignment.topCenter,
            child: Text(
              widget.description,
              style: style,
              maxLines: _expanded || !isLong ? null : 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (isLong)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: SacInkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: Text(
                      _expanded
                          ? 'activities.detail.see_less'.tr()
                          : 'activities.detail.see_more'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        fontWeight: FontWeight.w600,
                        color: SacAccent.of(context).color,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
