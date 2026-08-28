import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import 'package:sacdia_app/core/widgets/sac_pressable.dart';

import '../../domain/entities/faq_item.dart';
import 'faq_category_strip.dart';

class FaqItemCard extends StatelessWidget {
  const FaqItemCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  final FaqItem item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    final reduce = SacMotion.reduceMotionOf(context);

    return SacCard(
      padding: const EdgeInsets.all(16),
      borderColor: expanded ? scheme.primary.withValues(alpha: 0.45) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SacPressable(
            onTap: onTap,
            semanticLabel: item.question,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        item.question,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: c.text,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              letterSpacing: -0.2,
                            ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: reduce ? Duration.zero : SacMotion.standard,
                      curve: SacMotion.easeOut,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowDown01,
                        color: c.textTertiary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  faqCategoryLabel(item.category),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: reduce ? Duration.zero : SacMotion.standard,
            curve: SacMotion.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: MarkdownBody(
                      data: item.answer,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(Theme.of(context))
                              .copyWith(
                        p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: c.textSecondary,
                              height: 1.55,
                            ),
                        listBullet: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.primary),
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class FaqEmptyState extends StatelessWidget {
  const FaqEmptyState({super.key, required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SacCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: c.textTertiary,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            query.isEmpty
                ? 'support.faq_empty'.tr()
                : 'support.faq_no_results'.tr(args: [query]),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class FaqErrorState extends StatelessWidget {
  const FaqErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SacCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 48,
                color: c.error,
              ),
              const SizedBox(height: 12),
              Text(
                'support.errors.faq_load_failed'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: c.textSecondary,
                    ),
              ),
              const SizedBox(height: 16),
              SacButton(
                text: 'common.retry'.tr(),
                variant: SacButtonVariant.outline,
                icon: HugeIcons.strokeRoundedRefresh,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
