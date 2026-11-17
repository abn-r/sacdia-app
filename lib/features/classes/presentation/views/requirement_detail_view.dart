import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/class_requirement.dart';
import '../providers/classes_providers.dart';
import '../sheets/requirement_status_history_sheet.dart';
import '../widgets/requirement_status_panel.dart';

/// Detail of one requirement of a class: its state, the local field's note
/// when it was sent back, and the evidence files. Pending and sent-back
/// requirements show a fixed bar to add images or PDFs and send.
///
/// Opened by the member from their own class (`Navigator.push`) and by the
/// coach from the member's progress (route
/// `/home/grouped-class/class/:classId/member/:userId/requirement/:requirementId`,
/// through [RequirementDetailRouteView]).
class RequirementDetailView extends ConsumerStatefulWidget {
  final ClassRequirement requirement;
  final int classId;
  final int? enrollmentId;
  final String? targetUserId;

  /// Name of the member when a coach is looking, for the subtitle.
  final String? memberName;
  final bool isClassExpired;

  /// La clase ya está investida: el progreso queda en solo lectura.
  final bool isClassInvested;

  const RequirementDetailView({
    super.key,
    required this.requirement,
    required this.classId,
    this.enrollmentId,
    this.targetUserId,
    this.memberName,
    this.isClassExpired = false,
    this.isClassInvested = false,
  });

  @override
  ConsumerState<RequirementDetailView> createState() =>
      _RequirementDetailViewState();
}

class _RequirementDetailViewState extends ConsumerState<RequirementDetailView> {
  final _stagingManagerKey = GlobalKey<EvidenceStagingManagerState>();

  bool _hasUnsavedFiles = false;

  ClassProgressQuery get _progressQuery => ClassProgressQuery(
        classId: widget.classId,
        enrollmentId: widget.enrollmentId,
        targetUserId: widget.targetUserId,
      );

  /// The requirement as the server has it now; the one given is the fallback
  /// while the class reloads.
  ClassRequirement _liveRequirement() {
    final classWithProgress =
        ref.watch(classWithProgressProvider(_progressQuery)).value;
    for (final requirement in classWithProgress?.allRequirements ?? const []) {
      if (requirement.id == widget.requirement.id) return requirement;
    }
    return widget.requirement;
  }

  String _buildFileNameWithIndex(String originalName, int index) {
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'bin';
    final displayIndex = index.toString().padLeft(2, '0');
    return 'Evidencia $displayIndex.$ext';
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;
    SacSnackBar.show(context, message, isError: true);
  }

  bool _canSubmitFromStagingManager({
    required ClassRequirement requirement,
    required bool canModify,
  }) {
    final stagingState = _stagingManagerKey.currentState;
    if (stagingState != null) return stagingState.canSubmitForActionBar;

    return canModify &&
        requirement.files.isNotEmpty &&
        requirement.files.length <= requirement.maxFiles;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final notifierState =
        ref.watch(requirementNotifierProvider(_progressQuery));
    final classAsync = ref.watch(classWithProgressProvider(_progressQuery));
    final requirement = _liveRequirement();
    final isClassExpired =
        widget.isClassExpired || (classAsync.value?.isExpired ?? false);
    final isClassInvested =
        widget.isClassInvested || (classAsync.value?.isInvested ?? false);
    // El backend bloquea el progreso de una clase vencida o investida.
    final isReadOnly = isClassExpired || isClassInvested;
    final canModify = requirement.canUploadForClass(isClassExpired: isReadOnly);
    final isLoading = notifierState.isLoading;
    final description = requirement.description?.trim() ?? '';
    final memberName = widget.memberName?.trim() ?? '';

    ref.listen(
      requirementNotifierProvider(_progressQuery),
      (prev, next) {
        if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
          _showErrorSnackbar(context, next.errorMessage!);
        }
      },
    );

    return PopScope(
      canPop: !_hasUnsavedFiles,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await SacDialog.show(
          context,
          title: 'classes.requirement_detail.unsaved_files_title'.tr(),
          content: 'classes.requirement_detail.unsaved_files_body'.tr(),
          confirmIsDestructive: true,
          cancelLabel: 'classes.requirement_detail.stay_button'.tr(),
          confirmLabel: 'classes.requirement_detail.leave_button'.tr(),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: requirement.name,
          subtitle: memberName.isEmpty
              ? 'classes.grouped.req.subtitle'
                  .tr(namedArgs: {'max': '${requirement.maxFiles}'})
              : 'classes.grouped.req.subtitle_member'.tr(namedArgs: {
                  'member': memberName,
                  'max': '${requirement.maxFiles}',
                }),
          backgroundColor: c.background,
          frosted: true,
          actions: [
            SacPressable(
              listenOnly: true,
              child: IconButton(
                enableFeedback: false,
                tooltip: 'classes.status_history.title'.tr(),
                onPressed: () => showRequirementStatusHistorySheet(
                  context,
                  requirement: requirement,
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
        bottomNavigationBar: canModify
            ? EvidenceStagingActionBar(
                onPickImages: () =>
                    _stagingManagerKey.currentState?.pickImages(),
                onPickPdfs: () => _stagingManagerKey.currentState?.pickPdfs(),
                onSubmit: () =>
                    _stagingManagerKey.currentState?.submitForValidation(),
                canSubmit: _canSubmitFromStagingManager(
                  requirement: requirement,
                  canModify: canModify,
                ),
                isLoading: isLoading ||
                    (_stagingManagerKey.currentState?.isLoadingForActionBar ??
                        false),
              )
            : null,
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
                      if (description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Text(
                            description,
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              height: 1.45,
                              color: c.text,
                            ),
                          ),
                        ),
                      if (isReadOnly)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: _ClosedBanner(isExpired: isClassExpired),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: RequirementStatusPanel(
                          requirement: requirement,
                          isReadOnly: isReadOnly,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Text(
                          'classes.grouped.req.files'.tr().toUpperCase(),
                          style: TextStyle(
                            fontSize: SacFontSize.labelSmall,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                      EvidenceStagingManager(
                        key: _stagingManagerKey,
                        embeddedMode: true,
                        showActionBar: false,
                        existingFiles: requirement.files
                            .map(StagedFile.fromRequirementEvidence)
                            .toList(),
                        maxFiles: requirement.maxFiles,
                        isLoading: isLoading,
                        onUpload: (xFile, mimeType, onProgress) async {
                          if (isReadOnly) {
                            throw AppException(
                              message: tr('classes.errors.progress_locked'),
                            );
                          }
                          final success = await ref
                              .read(requirementNotifierProvider(_progressQuery)
                                  .notifier)
                              .uploadFile(
                                requirementId: requirement.id,
                                pickedFile: xFile,
                                mimeType: mimeType,
                                onProgress: onProgress,
                                skipInvalidation: true,
                              );
                          if (!success) {
                            throw AppException(
                              message: _uploadErrorMessage(
                                ref.read(
                                  requirementNotifierProvider(_progressQuery),
                                ),
                                requirement,
                              ),
                            );
                          }
                        },
                        onDeleteRemote: (fileId) async {
                          if (isReadOnly) return;
                          await ref
                              .read(requirementNotifierProvider(_progressQuery)
                                  .notifier)
                              .deleteFile(
                                requirementId: requirement.id,
                                fileId: fileId,
                              );
                        },
                        onSubmit: () async {
                          if (isReadOnly) return;
                          final success = await ref
                              .read(requirementNotifierProvider(_progressQuery)
                                  .notifier)
                              .submit(requirement.id);
                          if (!success) return;
                          if (!context.mounted) return;
                          SacSnackBar.show(
                            context,
                            'classes.requirement_detail.submit_success'.tr(),
                            isSuccess: true,
                          );
                          Navigator.pop(context);
                        },
                        fileNameBuilder: _buildFileNameWithIndex,
                        canModify: canModify,
                        onLocalFilesChanged: (hasLocal) {
                          if (_hasUnsavedFiles != hasLocal) {
                            setState(() => _hasUnsavedFiles = hasLocal);
                          }
                        },
                        onActionStateChanged: () {
                          if (mounted) setState(() {});
                        },
                      ),
                      SizedBox(height: requirement.files.isEmpty ? 8 : 16),
                    ],
                  ),
                ),

                // Block taps while deleting or sending; the action bar shows
                // the progress. No dimming over the whole screen.
                if (isLoading)
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

/// Mensaje que se muestra junto al archivo que no se pudo subir. Solo se lee
/// el `code` de negocio; el texto del backend sirve de respaldo.
String _uploadErrorMessage(
  RequirementOperationState state,
  ClassRequirement requirement,
) {
  switch (state.errorCode) {
    case 'CLASS_PROGRESS_LOCKED':
      return tr('classes.errors.progress_locked');
    case 'CLASS_EVIDENCE_MAX_FILES_REACHED':
      return tr(
        'classes.errors.max_files_reached',
        namedArgs: {'max': '${requirement.maxFiles}'},
      );
  }
  final message = state.errorMessage?.trim();
  return (message == null || message.isEmpty)
      ? tr('classes.errors.upload_failed')
      : message;
}

/// Aviso de clase cerrada (vencida o investida): el progreso es de solo
/// lectura y la app no deja subir ni enviar evidencias.
class _ClosedBanner extends StatelessWidget {
  final bool isExpired;

  const _ClosedBanner({required this.isExpired});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final ink = isExpired ? c.onErrorContainer : c.onInfoContainer;
    return SacSummaryBox(
      color: isExpired ? c.errorContainer : c.infoContainer,
      child: Text(
        isExpired
            ? 'classes.requirement_detail.expired_banner'.tr()
            : 'classes.requirement_detail.invested_banner'.tr(),
        style: TextStyle(
          fontSize: SacFontSize.bodySmall,
          fontWeight: FontWeight.w600,
          color: ink,
          height: 1.35,
        ),
      ),
    );
  }
}
