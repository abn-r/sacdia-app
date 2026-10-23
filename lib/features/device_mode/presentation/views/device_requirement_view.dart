import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/errors/user_error_message.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../classes/domain/entities/class_requirement.dart';
import '../../../classes/presentation/providers/classes_providers.dart';
import '../../../classes/presentation/widgets/requirement_status_badge.dart';
import '../providers/device_connectivity_provider.dart';

/// Evidencias de un requisito: el menor toma o elige fotos (o un PDF), las sube
/// y las ENVÍA a validación; el coordinador o el campo local validan como
/// siempre. Cada subida avisa a sus tutores (lo hace el servidor).
///
/// Sin red todo es de solo lectura: no se encola nada. Una subida o envío
/// rechazado por el servidor muestra su mensaje; si la vinculación se perdió,
/// el interceptor ya devolvió el teléfono a la pantalla de vinculación.
class DeviceRequirementView extends ConsumerStatefulWidget {
  const DeviceRequirementView({
    super.key,
    required this.classId,
    required this.requirementId,
    this.enrollmentId,
  });

  final int classId;
  final int requirementId;
  final int? enrollmentId;

  @override
  ConsumerState<DeviceRequirementView> createState() =>
      _DeviceRequirementViewState();
}

class _DeviceRequirementViewState extends ConsumerState<DeviceRequirementView> {
  bool _hasUnsavedFiles = false;

  ClassProgressQuery get _query => ClassProgressQuery(
        classId: widget.classId,
        enrollmentId: widget.enrollmentId,
      );

  ClassRequirement? _find(AsyncValue<dynamic> async) {
    final klass = async.valueOrNull;
    if (klass == null) return null;
    for (final module in klass.modules) {
      for (final requirement in module.requirements) {
        if (requirement.id == widget.requirementId) {
          return requirement as ClassRequirement;
        }
      }
    }
    return null;
  }

  String _fileName(String originalName, int index) {
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'bin';
    return 'Evidencia ${index.toString().padLeft(2, '0')}.$ext';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final async = ref.watch(classWithProgressProvider(_query));
    final notifier = ref.watch(requirementNotifierProvider(_query));
    final online = isDeviceOnline(ref.watch(deviceOnlineProvider));
    final requirement = _find(async);
    final expired = async.valueOrNull?.isExpired ?? false;

    ref.listen(requirementNotifierProvider(_query), (_, next) {
      if (next.errorMessage == null || !mounted) return;
      // Nunca el texto crudo del servidor: se traduce por `code` y, sin uno
      // conocido, un mensaje genérico (también para 403 PRINCIPAL_SCOPE_DENIED).
      SacSnackBar.show(
        context,
        userErrorMessage(
          ServerFailure(message: '', errorCode: next.errorCode),
          // Cualquier 403 de un teléfono (PRINCIPAL_SCOPE_DENIED o
          // GUARD_PERMISSION_DENIED) es «no disponible»; el resto, genérico.
          fallbackKey: 'device.requirement.errors.action_failed',
        ),
        isError: true,
      );
    });

    return PopScope(
      canPop: !_hasUnsavedFiles,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await SacDialog.show(
          context,
          title: 'classes.requirement_detail.unsaved_files_title'.tr(),
          content: 'classes.requirement_detail.unsaved_files_body'.tr(),
          confirmIsDestructive: true,
          cancelLabel: 'classes.requirement_detail.stay_button'.tr(),
          confirmLabel: 'classes.requirement_detail.leave_button'.tr(),
        );
        if (leave == true && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: 'device.requirement.title'.tr(),
        ),
        body: _body(context, async, requirement, notifier, online, expired),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AsyncValue<dynamic> async,
    ClassRequirement? requirement,
    RequirementOperationState notifier,
    bool online,
    bool expired,
  ) {
    final c = context.sac;
    if (async.isLoading && requirement == null) {
      return const Center(child: SacLoading());
    }
    if (requirement == null) {
      return SacEmptyState(
        key: const ValueKey('device_requirement_missing'),
        title: 'device.requirement.not_found'.tr(),
        icon: HugeIcons.strokeRoundedAlert02,
        actionLabel: 'common.retry'.tr(),
        actionVariant: SacButtonVariant.outline,
        onAction: () => ref.invalidate(classWithProgressProvider(_query)),
      );
    }

    final canModify =
        online && requirement.canUploadForClass(isClassExpired: expired);
    final textTheme = Theme.of(context).textTheme;
    final feedback =
        requirement.observationComment ?? requirement.rejectionReason;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      requirement.name,
                      key: const ValueKey('device_requirement_name'),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  RequirementStatusBadge(status: requirement.status),
                ],
              ),
              if ((requirement.description ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  requirement.description!,
                  style: textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
              if (feedback != null && feedback.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  key: const ValueKey('device_requirement_feedback'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(feedback, style: textTheme.bodyMedium),
                ),
              ],
              if (!online) ...[
                const SizedBox(height: 8),
                Text(
                  'device.requirement.offline_readonly'.tr(),
                  key: const ValueKey('device_requirement_offline'),
                  style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: EvidenceStagingManager(
            key: ValueKey('device_staging_${requirement.id}'),
            existingFiles: requirement.files
                .map(StagedFile.fromRequirementEvidence)
                .toList(),
            maxFiles: requirement.maxFiles,
            isLoading: notifier.isLoading,
            canModify: canModify,
            fileNameBuilder: _fileName,
            onLocalFilesChanged: (hasLocal) {
              if (_hasUnsavedFiles != hasLocal) {
                setState(() => _hasUnsavedFiles = hasLocal);
              }
            },
            onUpload: (file, mimeType, onProgress) async {
              if (!canModify) {
                throw StateError('Cannot upload evidence right now');
              }
              final ok = await ref
                  .read(requirementNotifierProvider(_query).notifier)
                  .uploadFile(
                    requirementId: requirement.id,
                    pickedFile: file,
                    mimeType: mimeType,
                    onProgress: onProgress,
                    skipInvalidation: true,
                  );
              if (!ok) throw Exception(tr('classes.errors.upload_failed'));
            },
            onDeleteRemote: (fileId) async {
              if (!canModify) return;
              await ref
                  .read(requirementNotifierProvider(_query).notifier)
                  .deleteFile(requirementId: requirement.id, fileId: fileId);
            },
            onSubmit: () async {
              if (!canModify) return;
              final ok = await ref
                  .read(requirementNotifierProvider(_query).notifier)
                  .submit(requirement.id);
              if (!ok || !context.mounted) return;
              SacSnackBar.show(
                context,
                'classes.requirement_detail.submit_success'.tr(),
                backgroundColor: AppColors.validatedColor,
              );
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }
}
