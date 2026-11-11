import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../../../core/errors/forbidden.dart';
import '../../../enrollment/presentation/providers/enrollment_providers.dart';
import '../../../virtual_card/presentation/utils/share_position_origin.dart';
import '../../domain/entities/finance_export.dart';
import '../providers/finance_export_providers.dart';
import '../providers/finances_providers.dart';
import '../utils/finance_export_files.dart';

/// Abre el menú del mes de Finanzas: exportar a Excel/PDF y ver el informe.
///
/// [onOpenReport] recibe el id de la inscripción activa y navega a la lista de
/// informes mensuales.
Future<void> showFinanceMenuSheet(
  BuildContext context, {
  required ValueChanged<String> onOpenReport,
}) {
  return showSacSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => FinanceMenuSheet(onOpenReport: onOpenReport),
  );
}

class FinanceMenuSheet extends ConsumerWidget {
  const FinanceMenuSheet({super.key, required this.onOpenReport});

  final ValueChanged<String> onOpenReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sac = context.sac;
    final selected = ref.watch(selectedMonthProvider);
    final running = ref.watch(financeExportProvider).running;
    final enrollmentId = ref.watch(currentEnrollmentProvider).value?.endpointId;
    final hasReport = enrollmentId != null && enrollmentId != '0';
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final monthLabel = DateFormat('MMMM yyyy').format(
      DateTime(selected.year, selected.month),
    );

    return PopScope(
      canPop: running == null,
      child: Container(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 20 + bottomPadding),
        decoration: BoxDecoration(
          color: sac.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXL),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SacSheetHeader(
              title: 'finances.menu.title'.tr(),
              subtitle: monthLabel[0].toUpperCase() + monthLabel.substring(1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  for (final format in FinanceExportFormat.values)
                    _MenuTile(
                      icon: format == FinanceExportFormat.xlsx
                          ? HugeIcons.strokeRoundedXls01
                          : HugeIcons.strokeRoundedPdf01,
                      label: format == FinanceExportFormat.xlsx
                          ? 'finances.menu.export_excel'.tr()
                          : 'finances.menu.export_pdf'.tr(),
                      isLoading: running == format,
                      enabled: running == null,
                      onTap: (tileContext) => _export(tileContext, ref, format),
                    ),
                  if (hasReport)
                    _MenuTile(
                      icon: HugeIcons.strokeRoundedFile01,
                      label: 'finances.menu.view_report'.tr(),
                      enabled: running == null,
                      onTap: (tileContext) {
                        Navigator.of(tileContext).pop();
                        onOpenReport(enrollmentId);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(
    BuildContext tileContext,
    WidgetRef ref,
    FinanceExportFormat format,
  ) async {
    // Todo lo que se usa tras el await se toma ANTES: el sheet puede cerrarse.
    final messenger = ScaffoldMessenger.of(tileContext);
    final navigator = Navigator.of(tileContext);
    final notifier = ref.read(financeExportProvider.notifier);
    final sharer = ref.read(financeExportSharerProvider);
    final grace = ref.read(financeExportCleanupGraceProvider);
    final origin = sharePositionOriginForContext(tileContext);

    final result = await notifier.export(format);
    if (result == null) return;

    final failure = result.failure;
    if (failure != null || result.file == null) {
      if (navigator.mounted) navigator.pop();
      SacSnackBar.showMessenger(
        messenger,
        failure != null && isForbiddenFailure(failure)
            ? 'finances.export.forbidden'.tr()
            : 'finances.export.error'.tr(),
        isError: true,
      );
      return;
    }

    final file = result.file!;
    try {
      if (tileContext.mounted) {
        await sharer.share(
          file: file,
          fileName: result.fileName!,
          mimeType: result.mimeType!,
          sharePositionOrigin: origin,
        );
      }
    } catch (_) {
      SacSnackBar.showMessenger(
        messenger,
        'finances.export.error'.tr(),
        isError: true,
      );
    } finally {
      // El archivo lleva los números del club: no se deja en el temporal.
      unawaited(deleteFinanceExportFiles([file], grace: grace));
    }
    if (navigator.mounted) navigator.pop();
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    this.enabled = true,
  });

  final HugeIconData icon;
  final String label;
  final bool isLoading;
  final bool enabled;
  final void Function(BuildContext tileContext) onTap;

  @override
  Widget build(BuildContext context) {
    final sac = context.sac;
    final accent = SacAccent.of(context).color;

    return Opacity(
      opacity: enabled || isLoading ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: SacInkWell(
          onTap: enabled ? () => onTap(context) : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: isLoading
                          ? const SacLoadingSmall()
                          : HugeIcon(icon: icon, size: 20, color: accent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: sac.text,
                          ),
                    ),
                  ),
                  if (!isLoading)
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowRight01,
                      size: 16,
                      color: sac.textTertiary,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
