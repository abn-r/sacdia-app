import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/sac_back_button.dart';
import '../providers/certification_requirement_providers.dart';

/// Vista de cierre de una certificación (Task 12): sube el comprobante de
/// junta (board proof) y envía la inscripción a revisión final.
///
/// LIMITACIÓN CONOCIDA: el backend no expone el comprobante ya subido en un
/// endpoint de lectura, así que esta vista siempre arranca sin archivos
/// "existentes" — igual que los componentes FILE_EVIDENCE (ver
/// `certification_component_field.dart`). El botón "Enviar" de
/// [EvidenceStagingManager] sube el archivo (presign → PUT → confirm) y,
/// al completarse, dispara `submit-final`.
class CertificationCloseoutView extends ConsumerWidget {
  final int certificationId;
  final String? certificationName;

  const CertificationCloseoutView({
    super.key,
    required this.certificationId,
    this.certificationName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(certificationCloseoutNotifierProvider(certificationId));
    final notifier = ref
        .read(certificationCloseoutNotifierProvider(certificationId).notifier);
    final c = context.sac;

    ref.listen(certificationCloseoutNotifierProvider(certificationId),
        (prev, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      if (next.submitSuccess && prev?.submitSuccess != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('certifications.closeout.submit_success'.tr()),
            backgroundColor: AppColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.of(context).pop();
      }
    });

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        leading: sacAutoBackButton(context),
        title: Text(
          'certifications.closeout.title'.tr(),
          style: TextStyle(fontWeight: FontWeight.w700, color: c.text),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (certificationName != null) ...[
                    Text(
                      certificationName!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedInformationCircle,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'certifications.closeout.description'.tr(),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: c.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: EvidenceStagingManager(
                existingFiles: const [],
                maxFiles: 1,
                canModify: !state.submitSuccess,
                isLoading: state.isUploading || state.isSubmitting,
                fileNameBuilder: (originalName, index) => originalName,
                onUpload: (xFile, mimeType, onProgress) async {
                  final size = await xFile.length();
                  final success = await notifier.uploadCloseoutEvidence(
                    filePath: xFile.path,
                    fileName: xFile.name,
                    mimeType: mimeType,
                    fileSize: size,
                    onProgress: onProgress,
                  );
                  if (!success) {
                    throw Exception(
                      'certifications.closeout.upload_failed'.tr(),
                    );
                  }
                },
                onDeleteRemote: (_) async {},
                onSubmit: () async {
                  await notifier.submitFinal();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
