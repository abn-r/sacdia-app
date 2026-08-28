import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';

import '../../domain/entities/class_honor.dart';

/// Acciones de especialidad anclada a un módulo: PDF + inscribir/continuar.
class ClassHonorActionsRow extends StatelessWidget {
  final ClassHonor honor;

  const ClassHonorActionsRow({super.key, required this.honor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  honor.honorName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  honor.relationType.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.ink500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (honor.hasMaterial)
            IconButton(
              tooltip: 'classes.honors.open_pdf'.tr(),
              onPressed: () => SacPdfViewer.show(
                context,
                pdfSource: honor.materialUrl!,
                title: honor.honorName,
              ),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedPdf01,
                size: 18,
                color: AppColors.ink600,
              ),
            )
          else
            Tooltip(
              message: 'classes.honors.no_pdf'.tr(),
              child: IconButton(
                onPressed: null,
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedPdf01,
                  size: 18,
                  color: AppColors.ink300,
                ),
              ),
            ),
          TextButton(
            onPressed: () => context.push(
              RouteNames.honorDetailPath(honor.honorId.toString()),
            ),
            child: Text(
              honor.isEnrolled
                  ? 'classes.honors.continue_honor'.tr()
                  : 'classes.honors.enroll'.tr(),
            ),
          ),
        ],
      ),
    );
  }
}
