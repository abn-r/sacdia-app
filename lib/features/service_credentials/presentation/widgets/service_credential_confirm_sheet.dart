import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_sheet.dart';

/// Confirmation in a bottom sheet: title, what will happen and two buttons,
/// the confirming one first (red when [destructive]), «Cancelar» below.
/// Resolves to `true` only when confirmed.
Future<bool> showServiceCredentialConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showSacSheet<bool>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
    ),
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(title: title, subtitle: body),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  destructive
                      ? SacButton.destructive(
                          key: const ValueKey('credential-sheet-confirm'),
                          text: confirmLabel,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        )
                      : SacButton.primary(
                          key: const ValueKey('credential-sheet-confirm'),
                          text: confirmLabel,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                  const SizedBox(height: 8),
                  SacButton.ghost(
                    key: const ValueKey('credential-sheet-cancel'),
                    text: 'common.cancel'.tr(),
                    onPressed: () => Navigator.of(ctx).pop(false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return confirmed ?? false;
}
