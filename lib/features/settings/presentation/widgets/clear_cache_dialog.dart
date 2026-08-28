import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/widgets/sac_dialog.dart';

/// Confirmation dialog for the destructive "borrar todos los datos" path.
///
/// Returns `true` when the user confirms, `false` or `null` otherwise.
Future<bool?> showClearCacheConfirmDialog(BuildContext context) {
  return SacDialog.show(
    context,
    title: 'settings.clear_cache_confirm_title'.tr(),
    content: 'settings.clear_cache_confirm_body'.tr(),
    confirmLabel: 'settings.clear_cache_all_data'.tr(),
    confirmIsDestructive: true,
  );
}
