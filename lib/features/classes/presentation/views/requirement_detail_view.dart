import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/class_requirement.dart';
import '../providers/classes_providers.dart';
import '../sheets/requirement_status_history_sheet.dart';
import '../widgets/requirement_status_badge.dart';

/// Vista de detalle de un requerimiento de clase progresiva.
///
/// Permite al usuario:
/// - Ver el estado actual y la linea de tiempo del requerimiento.
/// - Ver los archivos de evidencia subidos.
/// - Subir nuevos archivos cuando el requerimiento esta pendiente.
/// - Eliminar archivos en estado pendiente.
/// - Enviar el requerimiento a validacion.
///
/// Uses [EvidenceStagingManager] for file staging, upload, and submission.
class RequirementDetailView extends ConsumerStatefulWidget {
  /// Snapshot inicial usado solo para obtener el [requirementId] y como
  /// fallback mientras [classWithProgressProvider] no haya cargado aun.
  final ClassRequirement requirement;
  final int classId;

  const RequirementDetailView({
    super.key,
    required this.requirement,
    required this.classId,
  });

  @override
  ConsumerState<RequirementDetailView> createState() =>
      _RequirementDetailViewState();
}

class _RequirementDetailViewState extends ConsumerState<RequirementDetailView> {
  bool _hasUnsavedFiles = false;

  /// Devuelve el requerimiento vivo desde [classWithProgressProvider] si ya
  /// cargó, o el snapshot inicial del constructor como fallback.
  ClassRequirement _liveRequirement(AsyncValue<dynamic> classAsync) {
    return classAsync.whenData((classWithProgress) {
          for (final module in classWithProgress.modules) {
            for (final req in module.requirements) {
              if (req.id == widget.requirement.id) return req;
            }
          }
          return widget.requirement;
        }).valueOrNull ??
        widget.requirement;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final notifierState =
        ref.watch(requirementNotifierProvider(widget.classId));

    // Leer el provider en vivo — se actualiza automaticamente al invalidarse
    // tras cada upload / delete exitoso en el notifier.
    final classAsync = ref.watch(classWithProgressProvider(widget.classId));
    final requirement = _liveRequirement(classAsync);
    final canModify = requirement.status == RequirementStatus.pendiente ||
        requirement.status == RequirementStatus.rechazado;

    // Mostrar snackbar cuando hay error
    ref.listen(
      requirementNotifierProvider(widget.classId),
      (prev, next) {
        if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
          _showErrorSnackbar(context, next.errorMessage!);
        }
      },
    );

    final isLoading = notifierState.isLoading;

    return PopScope(
      canPop: !_hasUnsavedFiles,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('classes.requirement_detail.unsaved_files_title'.tr()),
            content: Text(
              'classes.requirement_detail.unsaved_files_body'.tr(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('classes.requirement_detail.stay_button'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text('classes.requirement_detail.leave_button'.tr()),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: c.background,
        appBar: AppBar(
          title: Text(
            'classes.requirement_detail.requirement_title'
                .tr(namedArgs: {'name': requirement.name}),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
            overflow: TextOverflow.ellipsis,
          ),
          leading: IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowLeft01,
              color: c.text,
              size: 22,
            ),
            onPressed: isLoading ? null : () => Navigator.pop(context),
            tooltip: 'common.back'.tr(),
          ),
          backgroundColor: c.background,
          surfaceTintColor: Colors.transparent,
          actions: [
            RequirementStatusBadge(status: requirement.status),
            const SizedBox(width: 16),
          ],
        ),
        body: Stack(
          children: [
            // Single scroll view for all content — meta card, timeline, and
            // evidence staging area are one continuous scrollable surface.
            // EvidenceStagingManager uses embeddedMode: true so it grows with
            // its content instead of claiming its own bounded scroll area.
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'classes.requirement_detail.detail_header'.tr(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: c.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          requirement.name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: c.text,
                                    height: 1.25,
                                  ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),
                  // Meta card con descripcion y metricas
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(
                      'classes.requirement_detail.detail_header'.tr(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: c.textSecondary,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),
                  _RequirementMetaCard(requirement: requirement),

                  const SizedBox(height: 16),

                  // Especialidad vinculada (si aplica)
                  if (requirement.type == RequirementType.honor &&
                      requirement.linkedHonorName != null)
                    _LinkedHonorSection(requirement: requirement),
                  

                  // Estado actual tappable — abre historial como bottom sheet
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Text(
                      'classes.requirement_detail.status_header'.tr(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: c.textSecondary,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _StatusChip(
                      requirement: requirement,
                      onTap: () => showRequirementStatusHistorySheet(
                        context,
                        requirement: requirement,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Archivos de evidencia
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'classes.requirement_detail.evidence_files_header'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                  ),

                  // Evidence staging — grows with content (no internal scroll).
                  // In embeddedMode the manager renders its action bar at the
                  // bottom of its own Column so it stays co-located with the
                  // file grid and scrolls as one unit.
                  EvidenceStagingManager(
                    embeddedMode: true,
                    existingFiles: requirement.files
                        .map(StagedFile.fromRequirementEvidence)
                        .toList(),
                    maxFiles: requirement.maxFiles,
                    isLoading: notifierState.isLoading,
                    // C-1: Pass onProgress through to the notifier so
                    // Dio reports progress.
                    // C-2: skipInvalidation prevents per-file provider
                    // refresh mid-batch.
                    // I-6: Throw on false so the staging manager catches
                    // the error.
                    onUpload: (xFile, mimeType, onProgress) async {
                      final success = await ref
                          .read(requirementNotifierProvider(widget.classId)
                              .notifier)
                          .uploadFile(
                            requirementId: requirement.id,
                            pickedFile: xFile,
                            mimeType: mimeType,
                            onProgress: onProgress,
                            skipInvalidation: true,
                          );
                      if (!success) throw Exception('Upload failed');
                    },
                    onDeleteRemote: (fileId) async {
                      await ref
                          .read(requirementNotifierProvider(widget.classId)
                              .notifier)
                          .deleteFile(
                            requirementId: requirement.id,
                            fileId: fileId,
                          );
                    },
                    onSubmit: () async {
                      final success = await ref
                          .read(requirementNotifierProvider(widget.classId)
                              .notifier)
                          .submit(requirement.id);
                      if (success && mounted) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      'classes.requirement_detail.submit_success'
                                          .tr()),
                                ),
                              ],
                            ),
                            backgroundColor: AppColors.secondary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                        // ignore: use_build_context_synchronously
                        Navigator.pop(context);
                      }
                    },
                    fileNameBuilder: (originalName, index) =>
                        _buildFileNameWithIndex(
                            requirement, originalName, index),
                    canModify: canModify,
                    onLocalFilesChanged: (hasLocal) =>
                        setState(() => _hasUnsavedFiles = hasLocal),
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Loading overlay
            if (isLoading)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(child: SacLoading()),
              ),
          ],
        ),
      ),
    );
  }

  // ── File naming helpers ─────────────────────────────────────────────────────

  /// Construye un nombre de archivo descriptivo para el backend/storage.
  ///
  /// Genera nombre con índice explícito (para batch uploads).
  String _buildFileNameWithIndex(
      ClassRequirement requirement, String originalName, int index) {
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'bin';
    final moduleName = _resolveModuleName(requirement.moduleId);
    final sectionName = _sanitize(requirement.name, 30);
    final initials = _resolveUserInitials();
    return 'evidencia_${index}_${_sanitize(moduleName, 20)}_${sectionName}_$initials.$ext';
  }

  /// Saneado de texto para nombres de archivo.
  String _sanitize(String text, int maxLen) {
    final raw = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return raw.substring(0, raw.length.clamp(0, maxLen));
  }

  /// Busca el nombre del modulo desde el provider de progreso.
  String _resolveModuleName(int moduleId) {
    final classAsync = ref.read(classWithProgressProvider(widget.classId));
    return classAsync.whenData((cp) {
          for (final m in cp.modules) {
            if (m.id == moduleId) return m.name;
          }
          return 'modulo';
        }).valueOrNull ??
        'modulo';
  }

  /// Extrae las iniciales del usuario autenticado.
  String _resolveUserInitials() {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user?.name == null || user!.name!.isEmpty) return 'NN';
    final parts = user.name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first
        .substring(0, parts.first.length.clamp(0, 2))
        .toUpperCase();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ── Meta card ─────────────────────────────────────────────────────────────────

class _RequirementMetaCard extends StatelessWidget {
  final ClassRequirement requirement;

  const _RequirementMetaCard({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (requirement.description != null &&
              requirement.description!.isNotEmpty) ...[
            Text(
              requirement.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.5,
                  ),
            ),
            const SizedBox(height: 14),
            Divider(color: c.divider),
            const SizedBox(height: 10),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // _MetaItem(
              //   icon: HugeIcons.strokeRoundedStar,
              //   label: 'Puntos clase',
              //   value: '${requirement.pointValue} pts',
              //   color: AppColors.accent,
              //   context: context,
              // ),
              // const SizedBox(width: 24),
              _MetaItem(
                icon: HugeIcons.strokeRoundedFiles01,
                label: 'classes.requirement_detail.file_limit_label'.tr(),
                value: '${requirement.maxFiles}',
                color: c.textSecondary,
                context: context,
              ),
              const SizedBox(width: 40),
              _MetaItem(
                icon: HugeIcons.strokeRoundedTag01,
                label: 'classes.requirement_detail.type_label'.tr(),
                value: _typeLabel(requirement.type),
                color: AppColors.primary,
                context: context,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _typeLabel(RequirementType type) {
    switch (type) {
      case RequirementType.honor:
        return 'classes.requirement_detail.type_honor'.tr();
      case RequirementType.service:
        return 'classes.requirement_detail.type_service'.tr();
      case RequirementType.general:
        return 'classes.requirement_detail.type_general'.tr();
    }
  }
}

class _MetaItem extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final String value;
  final Color color;
  final BuildContext context;

  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(icon: icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.sac.textTertiary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Especialidad vinculada ─────────────────────────────────────────────────────

class _LinkedHonorSection extends StatelessWidget {
  final ClassRequirement requirement;

  const _LinkedHonorSection({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompleted = requirement.linkedHonorCompleted ?? false;
    final color = isCompleted ? AppColors.secondary : AppColors.sacBlue;
    final bgColor = isCompleted
        ? AppColors.secondaryLight
        : (isDark ? AppColors.statusInfoBgDark : AppColors.statusInfoBgLight);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: HugeIcon(
                icon: isCompleted
                    ? HugeIcons.strokeRoundedCheckmarkCircle01
                    : HugeIcons.strokeRoundedAward01,
                size: 22,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'classes.requirement_detail.linked_honor_title'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: c.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  requirement.linkedHonorName!,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCompleted
                  ? 'classes.status.completed'.tr()
                  : 'classes.status.pending'.tr(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Chip tappable del estado actual ──────────────────────────────────────────

/// Chip compacto que muestra el estado actual del requerimiento.
///
/// Al tocarlo abre el [RequirementStatusHistorySheet] con el historial
/// de transiciones disponibles en la entidad.
class _StatusChip extends StatelessWidget {
  final ClassRequirement requirement;
  final VoidCallback onTap;

  const _StatusChip({
    required this.requirement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = _bgColor(isDark);
    final borderColor = _borderColor(isDark);
    final textColor = _textColor(isDark);

    return Semantics(
      button: true,
      label: 'classes.requirement_detail.semantics_status'
          .tr(namedArgs: {'status': _label}),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: _icon, size: 15, color: textColor),
              const SizedBox(width: 8),
              Text(
                _label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const Spacer(),
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                size: 15,
                color: c.textTertiary,
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  String get _label {
    switch (requirement.status) {
      case RequirementStatus.pendiente:
        return 'classes.status.pending'.tr();
      case RequirementStatus.enviado:
        return 'classes.status.sent'.tr();
      case RequirementStatus.validado:
        return 'classes.status.validated'.tr();
      case RequirementStatus.rechazado:
        return 'classes.status.rejected'.tr();
    }
  }

  Color _bgColor(bool isDark) {
    switch (requirement.status) {
      case RequirementStatus.pendiente:
        return AppColors.accentLight;
      case RequirementStatus.enviado:
        return isDark
            ? AppColors.statusInfoBgDark
            : AppColors.statusInfoBgLight;
      case RequirementStatus.validado:
        return AppColors.secondaryLight;
      case RequirementStatus.rechazado:
        return AppColors.errorLight;
    }
  }

  Color _borderColor(bool isDark) {
    switch (requirement.status) {
      case RequirementStatus.pendiente:
        return AppColors.accent.withValues(alpha: 0.4);
      case RequirementStatus.enviado:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case RequirementStatus.validado:
        return AppColors.secondary.withValues(alpha: 0.4);
      case RequirementStatus.rechazado:
        return AppColors.error.withValues(alpha: 0.4);
    }
  }

  Color _textColor(bool isDark) {
    switch (requirement.status) {
      case RequirementStatus.pendiente:
        return AppColors.accentDark;
      case RequirementStatus.enviado:
        return isDark ? AppColors.statusInfoTextDark : AppColors.statusInfoText;
      case RequirementStatus.validado:
        return AppColors.secondaryDark;
      case RequirementStatus.rechazado:
        return AppColors.errorDark;
    }
  }

  List<List<dynamic>> get _icon {
    switch (requirement.status) {
      case RequirementStatus.pendiente:
        return HugeIcons.strokeRoundedClock01;
      case RequirementStatus.enviado:
        return HugeIcons.strokeRoundedSent;
      case RequirementStatus.validado:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case RequirementStatus.rechazado:
        return HugeIcons.strokeRoundedCancel01;
    }
  }
}
