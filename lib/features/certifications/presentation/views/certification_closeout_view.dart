import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/sac_font_size.dart';
import '../../../../core/widgets/evidence_staging/evidence_footer_bar.dart';
import '../../../../core/widgets/evidence_staging/evidence_footer_presence.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_status.dart';
import '../providers/certification_requirement_providers.dart';
import '../providers/certifications_providers.dart';
import '../widgets/certification_status_panel.dart';

/// Closeout of a certification: the board record («Acta de la junta»). It
/// looks exactly like a requirement: status panel in a card, the description,
/// «Archivo · 0 de 1» with the «Agregar» tile and one action, «Enviar acta».
/// After sending it shows «En revisión final» and, once approved,
/// «Certificada».
///
/// LIMITACIÓN CONOCIDA: el backend no expone el acta ya subida en un endpoint
/// de lectura, así que la cuadrícula siempre arranca sin archivos existentes.
///
/// Route: `/certification/:certificationId/closeout?enrollmentId=`.
class CertificationCloseoutView extends ConsumerStatefulWidget {
  const CertificationCloseoutView({
    super.key,
    required this.certificationId,
    required this.enrollmentId,
    this.certificationName,
  });

  final int certificationId;
  final int enrollmentId;
  final String? certificationName;

  @override
  ConsumerState<CertificationCloseoutView> createState() =>
      _CertificationCloseoutViewState();
}

class _CertificationCloseoutViewState
    extends ConsumerState<CertificationCloseoutView> {
  final _managerKey = GlobalKey<EvidenceStagingManagerState>();
  bool _hasLocalFile = false;

  CertificationCloseoutQuery get _query => CertificationCloseoutQuery(
        certificationId: widget.certificationId,
        enrollmentId: widget.enrollmentId,
      );

  CertificationCloseoutNotifier get _notifier =>
      ref.read(certificationCloseoutNotifierProvider(_query).notifier);

  /// The closeout as a requirement: not sent, sent back, in final review or
  /// certified.
  CertificationStepInfo _info(CertificationEnrollmentStatus status) {
    final CertificationRequirementStatus mapped;
    if (status.isCertified) {
      mapped = CertificationRequirementStatus.approved;
    } else if (status.isUnderFinalReview) {
      mapped = CertificationRequirementStatus.submitted;
    } else if (status == CertificationEnrollmentStatus.changesRequested) {
      mapped = CertificationRequirementStatus.changesRequested;
    } else {
      mapped = CertificationRequirementStatus.draft;
    }
    return CertificationStepInfo(
      name: 'certifications.closeout.title'.tr(),
      status: mapped,
      reviewTitle: 'certifications.closeout.state_review'.tr(),
      validatedTitle: 'certifications.closeout.state_certified'.tr(),
    );
  }

  Future<bool> _confirmLeave() async {
    final confirm = await SacDialog.show(
      context,
      title: 'certifications.requirement_detail.unsaved_files_title'.tr(),
      content: 'certifications.requirement_detail.unsaved_files_body'.tr(),
      confirmIsDestructive: true,
      cancelLabel: 'certifications.requirement_detail.stay_button'.tr(),
      confirmLabel: 'certifications.requirement_detail.leave_button'.tr(),
    );
    return confirm == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final state = ref.watch(certificationCloseoutNotifierProvider(_query));
    final status = ref
            .watch(certificationProgressProvider(widget.certificationId))
            .value
            ?.status ??
        CertificationEnrollmentStatus.readyForCloseout;
    final canEdit = status.isCloseoutOpen && !state.submitSuccess;
    final isResend = status == CertificationEnrollmentStatus.changesRequested;
    final isBusy = state.isUploading || state.isSubmitting;
    final info = _info(status);
    final manager = _managerKey.currentState;

    ref.listen(certificationCloseoutNotifierProvider(_query), (prev, next) {
      final message = next.errorMessage;
      if (message != null && message.isNotEmpty) {
        SacSnackBar.show(context, message, isError: true);
        _notifier.clearError();
      }
      if (next.submitSuccess && prev?.submitSuccess != true) {
        HapticFeedback.mediumImpact();
        setState(() => _hasLocalFile = false);
        SacSnackBar.show(
          context,
          'certifications.closeout.submit_success'.tr(),
          isSuccess: true,
        );
        // Stay on the screen: it turns «En revisión final» in place.
      }
    });

    final canSend =
        canEdit && !isBusy && (manager?.canSubmitForActionBar ?? false);

    return PopScope(
      canPop: !_hasLocalFile,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: 'certifications.closeout.title'.tr(),
          subtitle: 'certifications.closeout.subtitle'.tr(),
          backgroundColor: c.background,
          frosted: true,
          actions: [
            SacPressable(
              listenOnly: true,
              child: IconButton(
                key: const ValueKey('certification-closeout-menu'),
                enableFeedback: false,
                tooltip: 'certifications.req.menu_states'.tr(),
                onPressed: () => showCertificationStatesSheet(
                  context,
                  info: info,
                  isReadOnly: !canEdit &&
                      !status.isUnderFinalReview &&
                      !status.isCertified,
                ),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedMoreHorizontal,
                  size: 20,
                  color: c.textSecondary,
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: EvidenceFooterPresence(
          visible: canEdit,
          child: EvidenceFooterBar(
            child: SacButton.primary(
              key: const ValueKey('certification-closeout-send'),
              text: isResend
                  ? 'core.evidence_staging.btn_resend'.tr()
                  : 'certifications.closeout.send'.tr(),
              icon: HugeIcons.strokeRoundedSent,
              isEnabled: canSend,
              isLoading: isBusy,
              onPressed: canSend
                  ? () => _managerKey.currentState?.submitForValidation()
                  : null,
            ),
          ),
        ),
        body: SacFrostedVeil(
          child: Builder(
            builder: (context) => Stack(
              children: [
                SingleChildScrollView(
                  padding:
                      EdgeInsets.only(top: SacTopBar.frostedInset(context)),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                        child: CertificationStatusPanel(info: info),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                        child: Text(
                          'certifications.closeout.description'.tr(),
                          key: const ValueKey('certification-closeout-text'),
                          style: TextStyle(
                            fontSize: SacFontSize.titleMedium,
                            height: 1.45,
                            color: c.text,
                          ),
                        ),
                      ),
                      if (canEdit) ...[
                        const SizedBox(height: 24),
                        EvidenceStagingManager(
                          key: _managerKey,
                          embeddedMode: true,
                          showActionBar: false,
                          existingFiles: const [],
                          maxFiles: 1,
                          canModify: canEdit,
                          isLoading: isBusy,
                          isResend: isResend,
                          sectionTitle:
                              'certifications.closeout.file_title'.tr(),
                          fileNameBuilder: (originalName, index) =>
                              originalName,
                          onUpload: (xFile, mimeType, onProgress) async {
                            final size = await xFile.length();
                            final success =
                                await _notifier.uploadCloseoutEvidence(
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
                            await _notifier.submitFinal();
                          },
                          onLocalFilesChanged: (hasLocal) {
                            if (_hasLocalFile != hasLocal) {
                              setState(() => _hasLocalFile = hasLocal);
                            }
                          },
                          onActionStateChanged: () {
                            if (mounted) setState(() {});
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                if (isBusy)
                  const Positioned.fill(
                    child: AbsorbPointer(child: SizedBox.expand()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
