import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';

/// Confirmation dialog for the destructive "borrar todos los datos" path.
///
/// Returns `true` when the user confirms, `false` or `null` otherwise.
///
/// We use [AlertDialog] (not [SacDialog]) here to match the style spec
/// in the task manifest — the feature requested an AlertDialog-based
/// confirm for this specific destructive variant.
Future<bool?> showClearCacheConfirmDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: context.sac.barrierColor,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(
        'settings.clear_cache_confirm_title'.tr(),
        style: const TextStyle(color: AppColors.error),
      ),
      content: Text('settings.clear_cache_confirm_body'.tr()),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('settings.clear_cache_all_data'.tr()),
        ),
      ],
    ),
  );
}
