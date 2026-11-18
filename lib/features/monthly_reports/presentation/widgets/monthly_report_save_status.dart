import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';

/// Estado del autoguardado del formulario de datos manuales.
enum MonthlyReportSaveState { idle, saving, saved, error }

/// Línea bajo el título: «Se guarda solo», «Guardando…», «✓ Guardado hace un
/// momento» o el error con su reintento.
class MonthlyReportSaveStatusLine extends StatelessWidget {
  const MonthlyReportSaveStatusLine({
    super.key,
    required this.state,
    required this.onRetry,
  });

  final MonthlyReportSaveState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final base = TextStyle(
      fontSize: SacFontSize.bodyMedium,
      height: 1.35,
      color: c.textSecondary,
    );

    final Widget line;
    switch (state) {
      case MonthlyReportSaveState.idle:
        line = Text('monthly_reports.form.autosave_hint'.tr(), style: base);
      case MonthlyReportSaveState.saving:
        line = Text('common.saving'.tr(), style: base);
      case MonthlyReportSaveState.saved:
        line = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              size: 14,
              color: c.onSuccessContainer,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'monthly_reports.form.saved_just_now'.tr(),
                style: base.copyWith(color: c.onSuccessContainer),
              ),
            ),
          ],
        );
      case MonthlyReportSaveState.error:
        line = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlertCircle,
              size: 14,
              color: c.onErrorContainer,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                'monthly_reports.form.save_error'.tr(),
                style: base.copyWith(color: c.onErrorContainer),
              ),
            ),
            const SizedBox(width: 8),
            SacInkWell(
              onTap: onRetry,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                child: Center(
                  child: Text(
                    'common.retry'.tr(),
                    style: base.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
    }

    return Semantics(
      liveRegion: true,
      container: true,
      child: AnimatedSwitcher(
        duration: SacMotion.switcher,
        child: KeyedSubtree(key: ValueKey(state), child: line),
      ),
    );
  }
}
