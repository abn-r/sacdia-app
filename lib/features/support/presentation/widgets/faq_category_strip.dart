import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

class FaqCategoryFilter {
  const FaqCategoryFilter({required this.category, required this.count});

  final String category;
  final int count;
}

class FaqCategoryStrip extends StatelessWidget {
  const FaqCategoryStrip({
    super.key,
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<FaqCategoryFilter> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < categories.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _FaqFilterChip(
              filter: categories[i],
              isActive: categories[i].category == selected,
              onTap: () => onSelected(categories[i].category),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqFilterChip extends StatefulWidget {
  const _FaqFilterChip({
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  final FaqCategoryFilter filter;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_FaqFilterChip> createState() => _FaqFilterChipState();
}

class _FaqFilterChipState extends State<_FaqFilterChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    final reduce = SacMotion.reduceMotionOf(context);
    final label =
        '${faqCategoryLabel(widget.filter.category)} (${widget.filter.count})';

    return Semantics(
      button: true,
      selected: widget.isActive,
      label: label,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: AnimatedContainer(
            duration: SacMotion.standard,
            curve: SacMotion.easeOut,
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isActive ? scheme.primary : c.surface,
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              border: Border.all(
                color: widget.isActive ? scheme.primary : c.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: faqCategoryIcon(widget.filter.category),
                  size: 15,
                  color: widget.isActive ? scheme.onPrimary : c.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: widget.isActive ? scheme.onPrimary : c.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String faqCategoryLabel(String category) =>
    'support.faq_category.$category'.tr();

HugeIconData faqCategoryIcon(String category) {
  switch (category) {
    case 'account':
      return HugeIcons.strokeRoundedUserCircle;
    case 'notifications':
      return HugeIcons.strokeRoundedNotification01;
    case 'offline':
      return HugeIcons.strokeRoundedCloud;
    case 'privacy':
      return HugeIcons.strokeRoundedShield01;
    case 'profile':
      return HugeIcons.strokeRoundedUserEdit01;
    case 'support':
      return HugeIcons.strokeRoundedCustomerSupport;
    case 'onboarding':
      return HugeIcons.strokeRoundedCompass01;
    default:
      return HugeIcons.strokeRoundedHelpCircle;
  }
}
