import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/sac_font_size.dart';
import '../../../../core/widgets/evidence_staging/evidence_footer_bar.dart';
import '../../../../core/widgets/evidence_staging/evidence_footer_presence.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../classes/presentation/widgets/grouped_class_skeleton.dart';
import '../../domain/entities/certification_requirement.dart';
import '../../domain/entities/certification_requirement_component.dart';
import '../../domain/entities/certification_status.dart';
import '../providers/certification_requirement_providers.dart';
import '../providers/certifications_providers.dart';
import '../widgets/certification_component_blocks.dart';
import '../widgets/certification_status_panel.dart';

/// One requirement of a certification, the same screen as a class
/// requirement: its state in a card (tap it for every state), the local
/// field's note once when it was sent back, the requirement text and then one
/// block per component (written answer, files, activity, honor, attestation).
///
/// One fixed action at the bottom sends it all: it uploads the staged files,
/// saves the answers and sends the requirement in a single flow. After
/// sending, the screen stays and turns «Enviado» in place (read-only, no
/// button).
///
/// Route: `/certification/:certificationId/requirement/:sectionId`.
class CertificationRequirementDetailView extends ConsumerStatefulWidget {
  const CertificationRequirementDetailView({
    super.key,
    required this.certificationId,
    required this.sectionId,
    required this.enrollmentId,
  });

  final int certificationId;
  final int sectionId;
  final int enrollmentId;

  @override
  ConsumerState<CertificationRequirementDetailView> createState() =>
      _CertificationRequirementDetailViewState();
}

class _CertificationRequirementDetailViewState
    extends ConsumerState<CertificationRequirementDetailView> {
  final Map<int, GlobalKey<EvidenceStagingManagerState>> _managerKeys = {};

  /// Components with staged files that were never uploaded.
  final Set<int> _componentsWithLocalFiles = {};

  CertificationRequirementQuery get _query => CertificationRequirementQuery(
        certificationId: widget.certificationId,
        sectionId: widget.sectionId,
        enrollmentId: widget.enrollmentId,
      );

  GlobalKey<EvidenceStagingManagerState> _keyFor(int componentId) =>
      _managerKeys.putIfAbsent(
        componentId,
        () => GlobalKey<EvidenceStagingManagerState>(),
      );

  CertificationRequirementNotifier get _notifier =>
      ref.read(certificationRequirementNotifierProvider(_query).notifier);

  List<CertificationRequirementComponent> _fileComponents(
    List<CertificationRequirementComponent> components,
  ) =>
      [
        for (final c in components)
          if (c.type == CertificationComponentType.fileEvidence) c,
      ];

  // ── Sending ────────────────────────────────────────────────────────────────

  /// The one action: uploads the staged files of each file component (each
  /// manager runs its own confirmation and progress sheet), then saves the
  /// answers and sends the requirement.
  Future<void> _send(List<CertificationRequirementComponent> components) async {
    final files = _fileComponents(components);
    if (files.isEmpty) {
      await _finalSubmit();
      return;
    }
    await _sendFilesFrom(files, 0);
  }

  Future<void> _sendFilesFrom(
    List<CertificationRequirementComponent> files,
    int index,
  ) async {
    if (index >= files.length) {
      await _finalSubmit();
      return;
    }
    final manager = _managerKeys[files[index].componentId]?.currentState;
    if (manager == null) {
      await _sendFilesFrom(files, index + 1);
      return;
    }
    // The manager calls its `onSubmit` once its files are uploaded.
    await manager.submitForValidation();
  }

  Future<void> _afterFilesUploaded(
    List<CertificationRequirementComponent> files,
    int index,
  ) =>
      _sendFilesFrom(files, index + 1);

  Future<void> _finalSubmit() async {
    final ok = await _notifier.submit();
    if (!ok || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(_componentsWithLocalFiles.clear);
    SacSnackBar.show(
      context,
      'certifications.requirement_detail.submit_success'.tr(),
      isSuccess: true,
    );
    // Stay on the screen: the requirement turns «Enviado» and the panel,
    // blocks and footer animate into the read-only state.
  }

  bool _canSend(
    List<CertificationRequirementComponent> components, {
    required bool isBusy,
  }) {
    if (isBusy) return false;
    for (final c in components) {
      if (!c.required) continue;
      if (c.type == CertificationComponentType.fileEvidence) {
        final manager = _managerKeys[c.componentId]?.currentState;
        final ok = manager?.canSubmitForActionBar ?? c.evidences.isNotEmpty;
        if (!ok) return false;
      } else if (!c.isComplete) {
        return false;
      }
    }
    return true;
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final state = ref.watch(certificationRequirementNotifierProvider(_query));
    final progress =
        ref.watch(certificationProgressProvider(widget.certificationId)).value;
    final requirement = state.requirement;
    final isClosed = progress?.status.isClosed ?? false;

    ref.listen(certificationRequirementNotifierProvider(_query), (prev, next) {
      final message = next.errorMessage;
      // A failed first load shows the error state instead (with retry).
      if (message != null && message.isNotEmpty && next.requirement != null) {
        SacSnackBar.show(context, message, isError: true);
        _notifier.clearError();
      }
    });

    String? moduleName;
    for (final m in progress?.modules ?? const []) {
      if (m.sections.any((s) => s.sectionId == widget.sectionId)) {
        moduleName = m.moduleName;
      }
    }

    final components = requirement == null
        ? const <CertificationRequirementComponent>[]
        : state.componentsWithLocalOverlay;
    final files = _fileComponents(components);
    final canEdit = requirement != null && requirement.canEdit && !isClosed;
    final isBusy = state.isSubmitting || state.isSavingDraft;
    final isResend =
        requirement?.status == CertificationRequirementStatus.changesRequested;

    final subtitle = files.isNotEmpty
        ? 'certifications.req.subtitle_files'
            .tr(namedArgs: {'max': '${files.first.maxFiles}'})
        : moduleName;

    final info = requirement == null
        ? null
        : CertificationStepInfo.fromRequirement(requirement);

    return PopScope(
      canPop: _componentsWithLocalFiles.isEmpty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && context.mounted) context.pop();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: requirement?.name ??
              'certifications.requirement_detail.title'.tr(),
          subtitle: subtitle,
          backgroundColor: c.background,
          frosted: true,
          actions: [
            if (info != null)
              SacPressable(
                listenOnly: true,
                child: IconButton(
                  key: const ValueKey('certification-requirement-menu'),
                  enableFeedback: false,
                  tooltip: 'certifications.req.menu_states'.tr(),
                  onPressed: () => showCertificationStatesSheet(
                    context,
                    info: info,
                    isReadOnly: isClosed,
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
          child: _ActionBar(
            components: components,
            isResend: isResend,
            isLoading: isBusy ||
                files.any(
                  (f) =>
                      _managerKeys[f.componentId]
                          ?.currentState
                          ?.isLoadingForActionBar ??
                      false,
                ),
            canSend: _canSend(components, isBusy: isBusy),
            fileCount: files.fold<int>(
              0,
              (sum, f) =>
                  sum +
                  (_managerKeys[f.componentId]
                          ?.currentState
                          ?.fileCountForActionBar ??
                      f.evidences.length),
            ),
            onSend: () => _send(components),
          ),
        ),
        body: SacFrostedVeil(
          child: Builder(
            builder: (context) {
              if (requirement == null || info == null) {
                final message = state.errorMessage;
                if (message != null && !state.isLoading) {
                  return SacErrorState(
                    title: 'certifications.req.load_error_title'.tr(),
                    message: userErrorMessage(message),
                    padding: SacTopBar.paddingBelowBar(
                      context,
                      const EdgeInsets.all(32),
                    ),
                    onRetry: _notifier.reload,
                  );
                }
                return const GroupedClassSkeleton(rows: 3);
              }
              return Stack(
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
                          child: CertificationStatusPanel(
                            info: info,
                            isReadOnly: isClosed,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: Text(
                            requirement.name,
                            key: const ValueKey(
                              'certification-requirement-description',
                            ),
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              height: 1.45,
                              color: c.text,
                            ),
                          ),
                        ),
                        for (final component in components)
                          _buildBlock(
                            component,
                            requirement,
                            files,
                            canEdit: canEdit,
                            isResend: isResend,
                            isBusy: isBusy,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                  // Block taps while sending; the bar shows the progress.
                  if (isBusy)
                    const Positioned.fill(
                      child: AbsorbPointer(child: SizedBox.expand()),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(
    CertificationRequirementComponent component,
    CertificationRequirement requirement,
    List<CertificationRequirementComponent> files, {
    required bool canEdit,
    required bool isResend,
    required bool isBusy,
  }) {
    final id = component.componentId;
    final response = component.response;
    switch (component.type) {
      case CertificationComponentType.textResponse:
        return CertificationTextBlock(
          key: ValueKey('certification-text-$id'),
          component: component,
          canEdit: canEdit,
          requirementName: requirement.name,
          onChanged: (text) => _notifier.updateComponentValue(
            CertificationComponentDraftInput(componentId: id, textValue: text),
          ),
        );
      case CertificationComponentType.fileEvidence:
        final index = files.indexWhere((f) => f.componentId == id);
        return CertificationFilesBlock(
          key: ValueKey('certification-files-$id'),
          managerKey: _keyFor(id),
          component: component,
          canEdit: canEdit,
          isResend: isResend,
          isLoading: isBusy,
          requirementName: requirement.name,
          title: 'certifications.req.files_title'.tr(),
          onUpload: (componentId, xFile, mimeType, onProgress) async {
            final size = await xFile.length();
            await _notifier.uploadComponentEvidence(
              componentId: componentId,
              filePath: xFile.path,
              fileName: xFile.name,
              mimeType: mimeType,
              fileSize: size,
              onProgress: onProgress,
            );
          },
          onDelete: (fileId) async {
            await _notifier.deleteComponentEvidence(fileId);
            await _notifier.reload();
          },
          onSubmit: () => _afterFilesUploaded(files, index),
          onLocalFilesChanged: (hasLocal) {
            final changed = hasLocal
                ? _componentsWithLocalFiles.add(id)
                : _componentsWithLocalFiles.remove(id);
            if (changed) setState(() {});
          },
          onActionStateChanged: () {
            if (mounted) setState(() {});
          },
        );
      case CertificationComponentType.linkedActivity:
        return CertificationActivityBlock(
          key: ValueKey('certification-activity-block-$id'),
          component: component,
          canEdit: canEdit,
          requirementName: requirement.name,
          query: CertificationActivityOptionsQuery(
            enrollmentId: widget.enrollmentId,
            sectionId: widget.sectionId,
            componentId: id,
          ),
          selectedId: response?.linkedActivityId,
          onChanged: (activityId) => _notifier.updateComponentValue(
            CertificationComponentDraftInput(
              componentId: id,
              linkedActivityId: activityId,
            ),
          ),
        );
      case CertificationComponentType.linkedHonor:
        return CertificationHonorBlock(
          key: ValueKey('certification-honor-block-$id'),
          component: component,
          canEdit: canEdit,
          requirementName: requirement.name,
          selectedId: response?.linkedUserHonorId,
          onChanged: (userHonorId) => _notifier.updateComponentValue(
            CertificationComponentDraftInput(
              componentId: id,
              linkedUserHonorId: userHonorId,
            ),
          ),
        );
      case CertificationComponentType.attestation:
        return CertificationAttestationBlock(
          key: ValueKey('certification-attestation-$id'),
          component: component,
          canEdit: canEdit,
          requirementName: requirement.name,
          confirmed: response?.attestationConfirmed ?? false,
          onChanged: (value) => _notifier.updateComponentValue(
            CertificationComponentDraftInput(
              componentId: id,
              attestationConfirmed: value,
            ),
          ),
        );
      case CertificationComponentType.autoValidation:
      case CertificationComponentType.unknown:
        return CertificationInfoBlock(
          key: ValueKey('certification-info-$id'),
          component: component,
          requirementName: requirement.name,
        );
    }
  }
}

/// The single fixed action: «Enviar N archivos» when the requirement only
/// asks for files, «Enviar respuesta» when it only asks for text, «Enviar»
/// otherwise and «Reenviar» after it was sent back.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.components,
    required this.isResend,
    required this.isLoading,
    required this.canSend,
    required this.fileCount,
    required this.onSend,
  });

  final List<CertificationRequirementComponent> components;
  final bool isResend;
  final bool isLoading;
  final bool canSend;
  final int fileCount;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final asked = [
      for (final c in components)
        if (c.type != CertificationComponentType.autoValidation &&
            c.type != CertificationComponentType.unknown)
          c.type,
    ];
    final onlyFiles = asked.isNotEmpty &&
        asked.every((t) => t == CertificationComponentType.fileEvidence);
    final onlyText = asked.isNotEmpty &&
        asked.every((t) => t == CertificationComponentType.textResponse);

    if (onlyFiles) {
      return EvidenceStagingActionBar(
        isResend: isResend,
        fileCount: fileCount,
        canSubmit: canSend,
        isLoading: isLoading,
        onSubmit: onSend,
      );
    }
    final text = isResend
        ? 'core.evidence_staging.btn_resend'.tr()
        : onlyText
            ? 'certifications.req.send_answer'.tr()
            : 'certifications.req.send'.tr();
    return EvidenceFooterBar(
      child: SacButton.primary(
        key: const ValueKey('certification-send'),
        text: text,
        icon: HugeIcons.strokeRoundedSent,
        isEnabled: canSend && !isLoading,
        isLoading: isLoading,
        onPressed: canSend && !isLoading ? onSend : null,
      ),
    );
  }
}
