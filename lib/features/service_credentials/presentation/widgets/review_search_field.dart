import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/fixed_input_icon_slot.dart';

/// Search box of the review queue (person or club). The caller debounces.
class ReviewSearchField extends StatelessWidget {
  const ReviewSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: SacFontSize.titleSmall, color: c.text),
        decoration: InputDecoration(
          hintText: 'service_credentials.review.search_hint'.tr(),
          hintStyle: TextStyle(
            color: c.textTertiary,
            fontSize: SacFontSize.titleSmall,
          ),
          prefixIconConstraints: FixedInputIconSlot.constraints,
          prefixIcon: FixedInputIconSlot(
            icon: HugeIcons.strokeRoundedSearch01,
            color: c.textTertiary,
            iconSize: 20,
          ),
          suffixIconConstraints: FixedInputIconSlot.constraints,
          suffixIcon: ListenableBuilder(
            listenable: controller,
            builder: (_, __) => controller.text.isEmpty
                ? const SizedBox.shrink()
                : Semantics(
                    button: true,
                    label: 'common.clear'.tr(),
                    excludeSemantics: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onClear,
                      child: FixedInputIconSlot(
                        icon: HugeIcons.strokeRoundedCancel01,
                        color: c.textTertiary,
                        iconSize: 18,
                      ),
                    ),
                  ),
          ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        ),
      ),
    );
  }
}
