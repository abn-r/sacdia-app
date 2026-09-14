import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_filter_chip.dart';

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
            SacFilterChip(
              label: faqCategoryLabel(categories[i].category),
              count: categories[i].count,
              selected: categories[i].category == selected,
              icon: faqCategoryIcon(categories[i].category),
              onTap: () => onSelected(categories[i].category),
            ),
          ],
        ],
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
