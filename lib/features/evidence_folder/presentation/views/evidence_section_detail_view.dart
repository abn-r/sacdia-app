import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/evidence_file.dart';
import '../../domain/entities/evidence_section.dart';
import '../providers/evidence_folder_providers.dart';
import '../sheets/evidence_status_history_sheet.dart';
import '../widgets/section_status_badge.dart';

/// Vista de detalle de una sección de evidencias.
///
/// Permite al usuario:
/// - Ver el estado actual y la línea de tiempo de la sección.
/// - Ver los archivos subidos en un grid de miniaturas.
/// - Subir nuevos archivos (imagen desde cámara/galería o PDF) cuando
///   la sección está pendiente y la carpeta está abierta.
/// - Eliminar archivos en estado pendiente.
/// - Enviar la sección a validación.
class EvidenceSectionDetailView extends ConsumerStatefulWidget {
  final EvidenceSection section;
  final bool folderIsOpen;
  final String clubSectionId;

  const EvidenceSectionDetailView({
    super.key,
    required this.section,
    required this.folderIsOpen,
    required this.clubSectionId,
  });

  @override
  ConsumerState<EvidenceSectionDetailView> createState() =>
      _EvidenceSectionDetailViewState();
}

class _EvidenceSectionDetailViewState
    extends ConsumerState<EvidenceSectionDetailView> {
  /// Tracks whether there are locally staged files (for PopScope).
  bool _hasUnsavedFiles = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final notifierState =
        ref.watch(evidenceSectionNotifierProvider(widget.clubSectionId));

    final canModify = (widget.section.status == EvidenceSectionStatus.pending ||
            widget.section.status == EvidenceSectionStatus.rejected) &&
        widget.folderIsOpen;

    // Mostrar snackbar cuando hay error
    ref.listen(
      evidenceSectionNotifierProvider(widget.clubSectionId),
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
            title: Text('evidence_folder.unsaved_files_dialog.title'.tr()),
            content: Text(
              'evidence_folder.unsaved_files_dialog.message'.tr(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('evidence_folder.stay'.tr()),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: Text('evidence_folder.exit'.tr()),
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
            'evidence_folder.section_title'.tr(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700, color: AppColors.sacRed),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: c.background,
          surfaceTintColor: Colors.transparent,
          actions: [
            SectionStatusBadge(status: widget.section.status),
            const SizedBox(width: 16),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bloque de título — igual al patrón de clases
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'evidence_folder.section_detail_label'.tr(),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: c.textSecondary,
                                    letterSpacing: 0.8,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.section.name,
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

                  // Descripción + métricas
                  _SectionMetaCard(section: widget.section),

                  const SizedBox(height: 16),

                  // Estado actual del sección (chip visual, solo lectura)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Text(
                    'evidence_folder.section_status_label'.tr(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: c.textSecondary,
                          letterSpacing: 0.8,
                        ),
                  ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _EvidenceStatusChip(
                      status: widget.section.status,
                      onTap: () => showEvidenceStatusHistorySheet(
                        context,
                        section: widget.section,
                      ),
                    ),
                  ),

                  // Resultado de evaluación (solo lectura, si existe)
                  if (widget.section.status ==
                          EvidenceSectionStatus.validated ||
                      widget.section.lfApproverName != null ||
                      widget.section.unionApproverName != null) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Text(
                        'evidence_folder.evaluation_result_title'.tr(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _EvaluationResultCard(section: widget.section),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Archivos de evidencia header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'evidence_folder.evidence_files_title'.tr(),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                  ),

                  // Notas del revisor por archivo — solo si existen
                  _ReviewerNotesBlock(files: widget.section.files),

                  // EvidenceStagingManager en modo embebido — crece con su
                  // contenido sin reclamar su propia área de scroll.
                  EvidenceStagingManager(
                    embeddedMode: true,
                    existingFiles: widget.section.files
                        .map(StagedFile.fromEvidenceFile)
                        .toList(),
                    maxFiles: widget.section.maxFiles,
                    isLoading: isLoading,
                    canModify: canModify,
                    onLocalFilesChanged: (hasLocal) {
                      setState(() => _hasUnsavedFiles = hasLocal);
                    },
                    // C-1: Pass onProgress to the notifier so Dio
                    // reports progress.
                    // C-2: skipInvalidation prevents per-file provider
                    // refresh mid-batch.
                    // I-6: Throw on false so the staging manager
                    // catches the error.
                    onUpload: (xFile, mimeType, onProgress) async {
                      final success = await ref
                          .read(evidenceSectionNotifierProvider(
                                  widget.clubSectionId)
                              .notifier)
                          .uploadFile(
                            sectionId: widget.section.id,
                            pickedFile: xFile,
                            mimeType: mimeType,
                            onProgress: onProgress,
                            skipInvalidation: true,
                          );
                      if (!success) throw Exception('Upload failed');
                    },
                    onDeleteRemote: (fileId) async {
                      await ref
                          .read(evidenceSectionNotifierProvider(
                                  widget.clubSectionId)
                              .notifier)
                          .deleteFile(fileId: fileId);
                    },
                    onSubmit: () async {
                      final success = await ref
                          .read(evidenceSectionNotifierProvider(
                                  widget.clubSectionId)
                              .notifier)
                          .submitSection(widget.section.id);
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
                                    'evidence_folder.submit_success'.tr(namedArgs: {
                                      'sectionName': widget.section.name,
                                    }),
                                  ),
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
                    fileNameBuilder: (originalName, index) {
                      final ext = originalName.contains('.')
                          ? originalName.split('.').last.toLowerCase()
                          : 'bin';
                      final sectionName = widget.section.name
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                          .replaceAll(RegExp(r'_+'), '_')
                          .replaceAll(RegExp(r'^_|_$'), '');
                      final truncated = sectionName.substring(
                          0, sectionName.length.clamp(0, 30));
                      return 'evidencia_${index}_$truncated.$ext';
                    },
                  ),

                  SizedBox(
                    height: widget.section.files.isEmpty ? 8 : 16,
                  ),
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

class _SectionMetaCard extends StatelessWidget {
  final EvidenceSection section;

  const _SectionMetaCard({required this.section});

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
          if (section.description != null &&
              section.description!.isNotEmpty) ...[
            Text(
              section.description!,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _MetaItem(
                icon: HugeIcons.strokeRoundedStar,
                label: 'evidence_folder.points_label'.tr(),
                value: 'evidence_folder.points_value'.tr(namedArgs: {
                  'points': '${section.pointValue}',
                }),
                color: AppColors.accent,
                context: context,
              ),
              const SizedBox(width: 24),
              _MetaItem(
                icon: HugeIcons.strokeRoundedPercent,
                label: 'evidence_folder.weight_label'.tr(),
                value: '${section.percentage.toStringAsFixed(1)}%',
                color: AppColors.primary,
                context: context,
              ),
              const SizedBox(width: 24),
              _MetaItem(
                icon: HugeIcons.strokeRoundedFiles01,
                label: 'evidence_folder.limit_label'.tr(),
                value: 'evidence_folder.files_count'.tr(namedArgs: {
                  'count': '${section.maxFiles}',
                }),
                color: c.textSecondary,
                context: context,
              ),
            ],
          ),
        ],
      ),
    );
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

// ── Chip de estado actual (tappable) ─────────────────────────────────────────

/// Chip compacto que muestra el estado actual de la sección de evidencias.
///
/// Al tocarlo abre el [EvidenceStatusHistorySheet] con el historial de
/// transiciones de estado disponibles en la entidad.
class _EvidenceStatusChip extends StatelessWidget {
  final EvidenceSectionStatus status;
  final VoidCallback onTap;

  const _EvidenceStatusChip({
    required this.status,
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
      label: 'evidence_folder.status_semantics'.tr(namedArgs: {'label': _label}),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
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
    switch (status) {
      case EvidenceSectionStatus.pending:
        return 'evidence_folder.status.pending'.tr();
      case EvidenceSectionStatus.submitted:
        return 'evidence_folder.status.submitted'.tr();
      case EvidenceSectionStatus.preapprovedLf:
        return 'evidence_folder.status.preapproved'.tr();
      case EvidenceSectionStatus.validated:
        return 'evidence_folder.status.validated'.tr();
      case EvidenceSectionStatus.rejected:
        return 'evidence_folder.status.rejected'.tr();
    }
  }

  Color _bgColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return AppColors.accentLight;
      case EvidenceSectionStatus.submitted:
        return isDark
            ? AppColors.statusInfoBgDark
            : AppColors.statusInfoBgLight;
      case EvidenceSectionStatus.preapprovedLf:
        return isDark ? AppColors.darkSurfaceVariant : AppColors.accentLight;
      case EvidenceSectionStatus.validated:
        return AppColors.secondaryLight;
      case EvidenceSectionStatus.rejected:
        return AppColors.errorLight;
    }
  }

  Color _borderColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return AppColors.accent.withValues(alpha: 0.4);
      case EvidenceSectionStatus.submitted:
        return AppColors.sacBlue.withValues(alpha: 0.4);
      case EvidenceSectionStatus.preapprovedLf:
        return AppColors.accent.withValues(alpha: 0.5);
      case EvidenceSectionStatus.validated:
        return AppColors.secondary.withValues(alpha: 0.4);
      case EvidenceSectionStatus.rejected:
        return AppColors.error.withValues(alpha: 0.4);
    }
  }

  Color _textColor(bool isDark) {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return AppColors.accentDark;
      case EvidenceSectionStatus.submitted:
        return isDark ? AppColors.statusInfoTextDark : AppColors.statusInfoText;
      case EvidenceSectionStatus.preapprovedLf:
        return AppColors.accentDark;
      case EvidenceSectionStatus.validated:
        return AppColors.secondaryDark;
      case EvidenceSectionStatus.rejected:
        return AppColors.errorDark;
    }
  }

  List<List<dynamic>> get _icon {
    switch (status) {
      case EvidenceSectionStatus.pending:
        return HugeIcons.strokeRoundedClock01;
      case EvidenceSectionStatus.submitted:
        return HugeIcons.strokeRoundedSent;
      case EvidenceSectionStatus.preapprovedLf:
        return HugeIcons.strokeRoundedAnalytics01;
      case EvidenceSectionStatus.validated:
        return HugeIcons.strokeRoundedCheckmarkCircle01;
      case EvidenceSectionStatus.rejected:
        return HugeIcons.strokeRoundedCancel01;
    }
  }
}

// ── Tarjeta de resultado de evaluación (solo lectura) ─────────────────────────

class _EvaluationResultCard extends StatelessWidget {
  final EvidenceSection section;

  const _EvaluationResultCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dateFormat = DateFormat('d MMM yyyy, HH:mm', 'es');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.secondary.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Puntos obtenidos
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedStar,
                  size: 20,
                  color: AppColors.secondaryDark,
                ),
              ),
              const SizedBox(width: 12),
                  Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'evidence_folder.earned_points'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                  Text(
                    '${section.earnedPoints} / ${section.pointValue}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.secondaryDark,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Actores de aprobación dual-level
          if (section.lfApproverName != null ||
              section.unionApproverName != null) ...[
            const SizedBox(height: 12),
            Divider(
              color: AppColors.secondary.withValues(alpha: 0.25),
              height: 1,
            ),
            const SizedBox(height: 12),
            // LF actor — siempre presente cuando existe
            if (section.lfApproverName != null) ...[
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAnalytics01,
                    size: 13,
                    color: AppColors.accentDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'evidence_folder.trace.preapproved_by'.tr(namedArgs: {
                        'name': section.lfApproverName!,
                        'date': section.lfApprovedAt != null
                            ? ' · ${dateFormat.format(section.lfApprovedAt!.toLocal())}'
                            : '',
                      }),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.accentDark,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                    ),
                  ),
                ],
              ),
            ],
            // Union actor — presente solo cuando actuó la unión
            if (section.unionApproverName != null) ...[
              if (section.lfApproverName != null) const SizedBox(height: 8),
              Row(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedUserCheck01,
                    size: 13,
                    color: AppColors.secondaryDark,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'evidence_folder.trace.validated_by'.tr(namedArgs: {
                        'name': section.unionApproverName!,
                        'date': section.unionApprovedAt != null
                            ? ' · ${dateFormat.format(section.unionApprovedAt!.toLocal())}'
                            : '',
                      }),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.secondaryDark,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ],

          // Notas del evaluador
          if (section.evaluationNotes != null &&
              section.evaluationNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'evidence_folder.evaluator_notes'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              section.evaluationNotes!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryDark,
                    height: 1.5,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bloque de notas del revisor por archivo ────────────────────────────────────

/// Renderiza un callout por cada archivo que tenga [EvidenceFile.reviewerNote].
///
/// Si ningún archivo tiene nota, el widget no ocupa espacio (SizedBox.shrink).
/// Posicionado entre el header "Archivos de evidencia" y el [EvidenceStagingManager].
class _ReviewerNotesBlock extends StatelessWidget {
  final List<EvidenceFile> files;

  const _ReviewerNotesBlock({required this.files});

  @override
  Widget build(BuildContext context) {
    final filesWithNotes = files
        .where((f) => f.reviewerNote != null && f.reviewerNote!.isNotEmpty)
        .toList();

    if (filesWithNotes.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'evidence_folder.reviewer_comments'.tr(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.sac.textSecondary,
                  letterSpacing: 0.8,
                ),
          ),
          const SizedBox(height: 8),
          ...filesWithNotes.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ReviewerNoteCallout(file: f),
            ),
          ),
        ],
      ),
    );
  }
}

/// Callout compacto que muestra la nota del revisor para un archivo individual.
///
/// Usa fondo info (azul suave) para diferenciarse visualmente del card principal
/// sin resultar alarmante — el note es feedback constructivo, no un error.
/// Trunca el texto a 3 líneas con opción de expandir inline.
class _ReviewerNoteCallout extends StatefulWidget {
  final EvidenceFile file;

  const _ReviewerNoteCallout({required this.file});

  @override
  State<_ReviewerNoteCallout> createState() => _ReviewerNoteCalloutState();
}

class _ReviewerNoteCalloutState extends State<_ReviewerNoteCallout> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores info (azul suave) — dark-mode aware, reutiliza los tokens de
    // AppColors.statusInfoBg* que ya existen para el estado "enviado".
    final bgColor =
        isDark ? AppColors.statusInfoBgDark : AppColors.statusInfoBgLight;
    final borderColor =
        AppColors.sacBlue.withValues(alpha: isDark ? 0.3 : 0.35);
    final noteColor =
        isDark ? AppColors.statusInfoTextDark : AppColors.statusInfoText;
    final labelColor = isDark
        ? AppColors.statusInfoTextDark.withValues(alpha: 0.7)
        : AppColors.statusInfoText.withValues(alpha: 0.75);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera: ícono + nombre de archivo
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedComment01,
                size: 14,
                color: noteColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.file.fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          // Texto del note con truncado expandible
          Text(
            widget.file.reviewerNote!,
            maxLines: _expanded ? null : 3,
            overflow: _expanded ? null : TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: noteColor,
              height: 1.45,
            ),
          ),
          // "Ver más / Ver menos" solo si el note supera 3 líneas visualmente.
          // Usamos LayoutBuilder para detectar overflow real.
          _ExpandToggle(
            text: widget.file.reviewerNote!,
            expanded: _expanded,
            textStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: noteColor,
              height: 1.45,
            ),
            toggleColor: noteColor,
            onToggle: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
    );
  }
}

/// Muestra "Ver más" / "Ver menos" solo cuando el texto supera [maxLines].
///
/// Usa [LayoutBuilder] + [TextPainter] para detectar si el texto realmente
/// se trunca — evita mostrar el toggle cuando el note es corto.
class _ExpandToggle extends StatelessWidget {
  final String text;
  final bool expanded;
  final TextStyle textStyle;
  final Color toggleColor;
  final VoidCallback onToggle;

  static const int _maxLines = 3;

  const _ExpandToggle({
    required this.text,
    required this.expanded,
    required this.textStyle,
    required this.toggleColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tp = TextPainter(
          text: TextSpan(text: text, style: textStyle),
          maxLines: _maxLines,
          textDirection: ui.TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        final isOverflowing = tp.didExceedMaxLines;
        if (!isOverflowing) return const SizedBox.shrink();

        return GestureDetector(
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              expanded
                  ? 'evidence_folder.show_less'.tr()
                  : 'evidence_folder.show_more'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: toggleColor,
                decoration: TextDecoration.underline,
                decorationColor: toggleColor,
              ),
            ),
          ),
        );
      },
    );
  }
}
