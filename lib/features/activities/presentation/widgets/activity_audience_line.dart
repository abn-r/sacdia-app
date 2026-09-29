import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';

import '../../domain/entities/activity.dart';

final _assetCodePattern = RegExp(r'^(AV|CQ|GM)-\d{2}$');

String activityAudienceText(Activity activity) {
  if (activity.audience == 'board') {
    return 'activities.form.audience_board'.tr();
  }
  if (activity.audience == 'classes') {
    final names = activity.audienceClasses
        .map((item) => item.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isNotEmpty) return names.join(', ');
    return 'activities.form.audience_classes'.tr();
  }
  return 'activities.form.audience_all'.tr();
}

String? activityClassLogoAsset(ActivityAudienceClass item) {
  final code = item.assetCode?.trim().toUpperCase();
  if (code != null && _assetCodePattern.hasMatch(code)) {
    return 'assets/img/logos-clases/$code.png';
  }
  return AppColors.classLogoAsset(item.name);
}

/// Logos and names when the activity is for specific classes.
class ActivityAudienceClasses extends StatelessWidget {
  final Activity activity;

  const ActivityAudienceClasses({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.audience != 'classes' || activity.audienceClasses.isEmpty) {
      return Text(
        activityAudienceText(activity),
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final item in activity.audienceClasses)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ClassLogo(item: item),
              const SizedBox(width: 6),
              Text(
                item.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ClassLogo extends StatelessWidget {
  final ActivityAudienceClass item;

  const _ClassLogo({required this.item});

  @override
  Widget build(BuildContext context) {
    final asset = activityClassLogoAsset(item);
    if (asset == null) return const SizedBox.shrink();
    return Image.asset(
      asset,
      width: 28,
      height: 28,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
