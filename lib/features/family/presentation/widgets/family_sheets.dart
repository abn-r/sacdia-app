import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_sheet.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
);

/// Confirmation in a bottom sheet: title, what will happen and two buttons,
/// the confirming one first (red when [destructive]). Resolves to `true` only
/// when confirmed.
Future<bool> showFamilyConfirmSheet(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showSacSheet<bool>(
    context: context,
    shape: _sheetShape,
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
                          key: const ValueKey('family-sheet-confirm'),
                          text: confirmLabel,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        )
                      : SacButton.primary(
                          key: const ValueKey('family-sheet-confirm'),
                          text: confirmLabel,
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                  const SizedBox(height: 8),
                  SacButton.ghost(
                    text: cancelLabel ?? 'common.cancel'.tr(),
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

/// A one-time code in a sheet (to invite another guardian): the code, when
/// it expires, and share or copy.
Future<void> showFamilyCodeSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String code,
  required String expiresLabel,
  required VoidCallback onShare,
  required VoidCallback onCopied,
}) {
  return showSacSheet<void>(
    context: context,
    shape: _sheetShape,
    isScrollControlled: true,
    builder: (ctx) {
      final c = ctx.sac;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(title: title, subtitle: subtitle),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Column(
                  children: [
                    SelectableText(
                      code,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: SacFontSize.displaySmall,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: c.text,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      expiresLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SacButton.primary(
                      key: const ValueKey('family-code-share'),
                      text: 'family.detail.share'.tr(),
                      icon: HugeIcons.strokeRoundedShare08,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        onShare();
                      },
                    ),
                    const SizedBox(height: 8),
                    SacButton.outline(
                      key: const ValueKey('family-code-copy'),
                      text: 'family.detail.copy'.tr(),
                      icon: HugeIcons.strokeRoundedCopy01,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        onCopied();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
