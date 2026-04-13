import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/evidence_section.dart';
import '../providers/evidence_folder_providers.dart';
import '../widgets/section_status_badge.dart';
import '../widgets/status_timeline.dart';

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
    final notifierState = ref.watch(
        evidenceSectionNotifierProvider(widget.clubSectionId));

    final canModify =
        (widget.section.status == EvidenceSectionStatus.pendiente ||
            widget.section.status == EvidenceSectionStatus.rechazado) &&
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
            title: const Text('Archivos sin enviar'),
            content: const Text(
              'Tienes archivos sin enviar. ¿Seguro que quieres salir?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Quedarme'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Salir'),
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
            'Sección',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.sacRed
                ),
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
                          'Detalle de la sección',
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

                  const SizedBox(height: 26),

                  // Timeline de estado
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                    child: Text(
                      'Flujo de estado',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: StatusTimeline(
                      currentStatus: widget.section.status,
                      submittedByName: widget.section.submittedByName,
                      submittedAt: widget.section.submittedAt,
                      validatedByName: widget.section.validatedByName,
                      validatedAt: widget.section.validatedAt,
                      evaluatedByName: widget.section.evaluatedByName,
                      evaluatedAt: widget.section.evaluatedAt,
                      evaluationNotes: widget.section.evaluationNotes,
                    ),
                  ),

                  // Resultado de evaluación (solo lectura, si existe)
                  if (widget.section.status ==
                          EvidenceSectionStatus.evaluated ||
                      widget.section.evaluatedByName != null) ...[
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Text(
                        'Resultado de evaluación',
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
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
                      'Archivos de evidencia',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                    ),
                  ),

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
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      'Sección enviada a validación exitosamente'),
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                label: 'Puntos',
                value: '${section.pointValue} pts',
                color: AppColors.accent,
                context: context,
              ),
              const SizedBox(width: 24),
              _MetaItem(
                icon: HugeIcons.strokeRoundedPercent,
                label: 'Peso',
                value: '${section.percentage.toStringAsFixed(1)}%',
                color: AppColors.primary,
                context: context,
              ),
              const SizedBox(width: 24),
              _MetaItem(
                icon: HugeIcons.strokeRoundedFiles01,
                label: 'Límite',
                value: '${section.maxFiles} archivos',
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
                    'Puntos obtenidos',
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

          // Evaluador y fecha
          if (section.evaluatedByName != null) ...[
            const SizedBox(height: 12),
            Divider(
              color: AppColors.secondary.withValues(alpha: 0.25),
              height: 1,
            ),
            const SizedBox(height: 12),
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
                    'Evaluado por ${section.evaluatedByName}'
                    '${section.evaluatedAt != null ? " · ${dateFormat.format(section.evaluatedAt!.toLocal())}" : ""}',
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

          // Notas del evaluador
          if (section.evaluationNotes != null &&
              section.evaluationNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Notas del evaluador',
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
