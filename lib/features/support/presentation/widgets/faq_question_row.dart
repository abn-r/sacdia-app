import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/animations/motion_tokens.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/faq_item.dart';

/// A question inside a [SacGroupedSection] that opens its answer in place.
class FaqQuestionRow extends StatelessWidget {
  const FaqQuestionRow({
    super.key,
    required this.item,
    required this.expanded,
    required this.onTap,
    this.showCategory = false,
  });

  final FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  /// Shows the category under the question (search results mix them).
  final bool showCategory;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context);
    final reduce = SacMotion.reduceMotionOf(context);
    return Semantics(
      button: true,
      expanded: expanded,
      child: SacInkWell(
        onTap: onTap,
        pressedScale: SacMotion.rowPressScale,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 13, 10, 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.question,
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                            color: c.text,
                          ),
                        ),
                        if (showCategory) ...[
                          const SizedBox(height: 2),
                          Text(
                            'support.faq_category.${item.category}'.tr(),
                            style: TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: reduce ? Duration.zero : SacMotion.standard,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowDown01,
                        size: 18,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
              AnimatedSize(
                duration: reduce ? Duration.zero : SacMotion.standard,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: expanded
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8, right: 6),
                        child: MarkdownBody(
                          data: item.answer,
                          styleSheet:
                              MarkdownStyleSheet.fromTheme(theme).copyWith(
                            p: theme.textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
