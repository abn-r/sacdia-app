import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../domain/entities/adult_claim_code.dart';

/// Muestra UNA vez el código de acceso recién emitido (el servidor solo guarda
/// su huella: no se puede volver a ver). Copiar y compartir; el código vive solo
/// en memoria y no se escribe en ningún lado.
Future<void> showAdultClaimCodeSheet(
  BuildContext context, {
  required IssuedAdultClaimCode issued,
  required String personName,
}) {
  final expires = DateFormat.yMMMd(context.locale.toString())
      .add_jm()
      .format(issued.expiresAt.toLocal());
  final message = 'adult_claim.share_message'.tr(namedArgs: {
    'name': personName,
    'code': issued.code,
    'when': expires,
  });

  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final c = sheetContext.sac;
      final textTheme = Theme.of(sheetContext).textTheme;
      return Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedKey01,
                size: 32,
                color: SacAccent.of(sheetContext).color,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'adult_claim.code_sheet.title'.tr(),
              textAlign: TextAlign.center,
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'adult_claim.code_sheet.body'.tr(namedArgs: {'name': personName}),
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 20),
            SelectableText(
              issued.code,
              key: const ValueKey('adult_claim_issued_code'),
              textAlign: TextAlign.center,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'adult_claim.code_sheet.expires'.tr(namedArgs: {'when': expires}),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              'adult_claim.code_sheet.once'.tr(),
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: 20),
            SacButton.outline(
              key: const ValueKey('adult_claim_copy'),
              text: 'adult_claim.code_sheet.copy'.tr(),
              icon: HugeIcons.strokeRoundedCopy01,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: issued.code));
                if (sheetContext.mounted) {
                  SacSnackBar.show(
                    sheetContext,
                    'adult_claim.code_sheet.copied'.tr(),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            SacButton.primary(
              key: const ValueKey('adult_claim_share'),
              text: 'adult_claim.code_sheet.share'.tr(),
              icon: HugeIcons.strokeRoundedShare08,
              onPressed: () =>
                  SharePlus.instance.share(ShareParams(text: message)),
            ),
          ],
        ),
      );
    },
  );
}
