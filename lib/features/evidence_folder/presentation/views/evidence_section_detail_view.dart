import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../domain/entities/evidence_file.dart';
import '../../domain/entities/evidence_section.dart';
import '../providers/evidence_folder_providers.dart';
import '../widgets/evidence_folder_summary.dart';
import '../widgets/section_status_panel.dart';

import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
    this.requiresUnion = false,
  });

  /// `requires_union_confirmation` of the folder: adds the union step.
  final bool requiresUnion;

  @override
  ConsumerState<EvidenceSectionDetailView> createState() =>
      _EvidenceSectionDetailViewState();
}

class _EvidenceSectionDetailViewState
    extends ConsumerState<EvidenceSectionDetailView> {
  final _stagingManagerKey = GlobalKey<EvidenceStagingManagerState>();

  /// Tracks whether there are locally staged files (for PopScope).
  bool _hasUnsavedFiles = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final notifierState = ref.watch(
      evidenceSectionNotifierProvider(widget.clubSectionId),
    );

    final canModify = (widget.section.status == EvidenceSectionStatus.pending ||
            widget.section.status == EvidenceSectionStatus.rejected) &&
        widget.folderIsOpen;

    // Mostrar snackbar cuando hay error
    ref.listen(evidenceSectionNotifierProvider(widget.clubSectionId), (
      prev,
      next,
    ) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        _showErrorSnackbar(context, next.errorMessage!);
      }
    });

    final isLoading = notifierState.isLoading;

    return PopScope(
      canPop: !_hasUnsavedFiles,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await SacDialog.show(
          context,
          title: 'evidence_folder.unsaved_files_dialog.title'.tr(),
          content: 'evidence_folder.unsaved_files_dialog.message'.tr(),
          confirmIsDestructive: true,
          cancelLabel: 'evidence_folder.stay'.tr(),
          confirmLabel: 'evidence_folder.exit'.tr(),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: c.background,
        appBar: SacTopBar(
          title: widget.section.name,
          subtitle: 'evidence_folder.detail.subtitle'.tr(namedArgs: {
            'points': formatEvidencePoints(context, widget.section.pointValue),
            'max': '${widget.section.maxFiles}',
          }),
          backgroundColor: c.background,
          frosted: true,
        ),
        bottomNavigationBar: canModify
            ? EvidenceStagingActionBar(
                onPickImages: () {
                  _stagingManagerKey.currentState?.pickImages();
                },
                onPickPdfs: () {
                  _stagingManagerKey.currentState?.pickPdfs();
                },
                onSubmit: () {
                  _stagingManagerKey.currentState?.submitForValidation();
                },
                canSubmit: _canSubmitFromStagingManager(canModify),
                isLoading: notifierState.isLoading ||
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
                      if ((widget.section.description ?? '').trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                          child: Text(
                            widget.section.description!.trim(),
                            style: TextStyle(
                              fontSize: SacFontSize.titleMedium,
                              height: 1.45,
                              color: c.text,
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        child: EvidenceSectionStatusPanel(
                          section: widget.section,
                          folderIsOpen: widget.folderIsOpen,
                          requiresUnion: widget.requiresUnion,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                        child: Text(
                          'evidence_folder.detail.files'.tr().toUpperCase(),
                          style: TextStyle(
                            fontSize: SacFontSize.labelSmall,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                            color: c.textTertiary,
                          ),
                        ),
                      ),

                      // Notas del revisor por archivo — solo si existen
                      _ReviewerNotesBlock(files: widget.section.files),

                      // EvidenceStagingManager en modo embebido — crece con su
                      // contenido sin reclamar su propia área de scroll.
                      EvidenceStagingManager(
                        key: _stagingManagerKey,
                        embeddedMode: true,
                        showActionBar: false,
                        existingFiles: widget.section.files
                            .map(StagedFile.fromEvidenceFile)
                            .toList(),
                        maxFiles: widget.section.maxFiles,
                        isLoading: isLoading,
                        canModify: canModify,
                        onLocalFilesChanged: (hasLocal) {
                          setState(() => _hasUnsavedFiles = hasLocal);
                        },
                        onActionStateChanged: () {
                          if (mounted) setState(() {});
                        },
                        // C-1: Pass onProgress to the notifier so Dio
                        // reports progress.
                        // C-2: skipInvalidation prevents per-file provider
                        // refresh mid-batch.
                        // I-6: Throw on false so the staging manager
                        // catches the error.
                        onUpload: (xFile, mimeType, onProgress) async {
                          final success = await ref
                              .read(
                                evidenceSectionNotifierProvider(
                                  widget.clubSectionId,
                                ).notifier,
                              )
                              .uploadFile(
                                sectionId: widget.section.id,
                                pickedFile: xFile,
                                mimeType: mimeType,
                                onProgress: onProgress,
                                skipInvalidation: true,
                              );
                          if (!success) {
                            throw Exception(
                              tr('evidence_folder.errors.upload_failed'),
                            );
                          }
                        },
                        onDeleteRemote: (fileId) async {
                          await ref
                              .read(
                                evidenceSectionNotifierProvider(
                                  widget.clubSectionId,
                                ).notifier,
                              )
                              .deleteFile(fileId: fileId);
                        },
                        onSubmit: () async {
                          final success = await ref
                              .read(
                                evidenceSectionNotifierProvider(
                                  widget.clubSectionId,
                                ).notifier,
                              )
                              .submitSection(widget.section.id);
                          if (!success) return;
                          if (!context.mounted) return;
                          SacSnackBar.show(
                            context,
                            'evidence_folder.submit_success'.tr(
                              namedArgs: {
                                'sectionName': widget.section.name,
                              },
                            ),
                            isSuccess: true,
                          );
                          Navigator.pop(context);
                        },
                        fileNameBuilder: (originalName, index) {
                          final ext = originalName.contains('.')
                              ? originalName.split('.').last.toLowerCase()
                              : 'bin';
                          final displayIndex = index.toString().padLeft(2, '0');
                          return 'Evidencia $displayIndex.$ext';
                        },
                      ),

                      SizedBox(height: widget.section.files.isEmpty ? 8 : 16),
                    ],
                  ),
                ),

                // Block taps while deleting or sending; the action bar
                // shows the progress. No dimming over the whole screen.
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

  // ── Helpers ─────────────────────────────────────────────────────────────────

  bool _canSubmitFromStagingManager(bool canModify) {
    final stagingState = _stagingManagerKey.currentState;
    if (stagingState != null) return stagingState.canSubmitForActionBar;

    return canModify &&
        widget.section.files.isNotEmpty &&
        widget.section.files.length <= widget.section.maxFiles;
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    if (!mounted) return;
    SacSnackBar.show(
      context,
      message,
      isError: true,
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'evidence_folder.detail.file_notes'.tr(),
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
    final c = context.sac;

    // Colores info (contenedor azul) — dark-mode aware vía tokens semánticos.
    final bgColor = c.infoContainer;
    final borderColor = c.info.withValues(alpha: 0.35);
    final noteColor = c.onInfoContainer;
    final labelColor = c.onInfoContainer.withValues(alpha: 0.8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusXS),
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
                    fontSize: SacFontSize.labelSmall,
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
              fontSize: SacFontSize.bodySmall,
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
              fontSize: SacFontSize.bodySmall,
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
                fontSize: SacFontSize.labelSmall,
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
