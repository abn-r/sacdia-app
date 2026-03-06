import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../domain/entities/evidence_file.dart';
import '../../domain/entities/evidence_section.dart';
import '../providers/evidence_folder_providers.dart';
import '../widgets/evidence_file_grid.dart';
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
  final String clubInstanceId;

  const EvidenceSectionDetailView({
    super.key,
    required this.section,
    required this.folderIsOpen,
    required this.clubInstanceId,
  });

  @override
  ConsumerState<EvidenceSectionDetailView> createState() =>
      _EvidenceSectionDetailViewState();
}

class _EvidenceSectionDetailViewState
    extends ConsumerState<EvidenceSectionDetailView> {
  final _picker = ImagePicker();

  // Indica si una operación de subida está en curso (para UI local).
  bool _isUploading = false;

  /// La sección puede ser modificada solo si está pendiente Y la carpeta está abierta.
  bool get _canModify =>
      widget.section.status == EvidenceSectionStatus.pendiente &&
      widget.folderIsOpen;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final notifierState = ref.watch(
        evidenceSectionNotifierProvider(widget.clubInstanceId));

    // Mostrar snackbar cuando hay error
    ref.listen(
      evidenceSectionNotifierProvider(widget.clubInstanceId),
      (prev, next) {
        if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
          _showErrorSnackbar(context, next.errorMessage!);
        }
      },
    );

    final isLoading = notifierState.isLoading || _isUploading;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: Text(
          widget.section.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Descripción + métricas
                    _SectionMetaCard(section: widget.section),

                    const SizedBox(height: 16),

                    // Timeline de estado
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Text(
                        'Flujo de estado',
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
                      child: StatusTimeline(
                        currentStatus: widget.section.status,
                        submittedByName: widget.section.submittedByName,
                        submittedAt: widget.section.submittedAt,
                        validatedByName: widget.section.validatedByName,
                        validatedAt: widget.section.validatedAt,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Archivos
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Text(
                            'Archivos de evidencia',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                          ),
                          const Spacer(),
                          if (_canModify)
                            Text(
                              '${widget.section.files.length} / ${widget.section.maxFiles}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.section.remainingSlots == 0
                                    ? AppColors.error
                                    : c.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (widget.section.files.isEmpty)
                      _EmptyFiles(canModify: _canModify)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: EvidenceFileGrid(
                          files: widget.section.files,
                          canDelete: _canModify,
                          onDelete: _canModify
                              ? (file) => _confirmDelete(context, file)
                              : null,
                        ),
                      ),

                    // Espacio inferior para que los botones no tapen el contenido
                    const SizedBox(height: 160),
                  ],
                ),
              ),
            ],
          ),

          // Loading overlay
          if (isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(child: SacLoading()),
            ),
        ],
      ),

      // Bottom action bar
      bottomNavigationBar: _canModify
          ? _BottomActionBar(
              section: widget.section,
              isLoading: isLoading,
              onUploadImage: () => _pickImage(context),
              onUploadPdf: () => _pickPdf(context),
              onSubmit: () => _submit(context),
            )
          : null,
    );
  }

  // ── Acciones ─────────────────────────────────────────────────────────────────

  Future<void> _pickImage(BuildContext context) async {
    if (widget.section.remainingSlots == 0) {
      _showErrorSnackbar(
          context, 'Has alcanzado el límite de archivos para esta sección.');
      return;
    }

    final source = await _showImageSourceDialog(context);
    if (source == null) return;

    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked == null || !mounted) return;

      setState(() => _isUploading = true);

      final mimeType = picked.name.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';

      await ref
          .read(evidenceSectionNotifierProvider(widget.clubInstanceId).notifier)
          .uploadFile(
            sectionId: widget.section.id,
            pickedFile: picked,
            mimeType: mimeType,
          );
    } catch (e) {
      AppLogger.e('Error al seleccionar imagen', error: e);
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showErrorSnackbar(context, 'No se pudo seleccionar la imagen.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _pickPdf(BuildContext context) async {
    if (widget.section.remainingSlots == 0) {
      _showErrorSnackbar(
          context, 'Has alcanzado el límite de archivos para esta sección.');
      return;
    }

    // Usar image_picker para simplificar — en producción se puede añadir
    // file_picker para soporte nativo de PDFs.
    // Por ahora abrimos el file picker a través de galería y filtramos por mime.
    try {
      final XFile? picked = await _picker.pickMedia();
      if (picked == null || !mounted) return;

      // Verificar que sea PDF por extensión
      if (!picked.name.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        _showErrorSnackbar(context, 'Solo se permiten archivos PDF en esta opción.');
        return;
      }

      setState(() => _isUploading = true);

      await ref
          .read(evidenceSectionNotifierProvider(widget.clubInstanceId).notifier)
          .uploadFile(
            sectionId: widget.section.id,
            pickedFile: picked,
            mimeType: 'application/pdf',
          );
    } catch (e) {
      AppLogger.e('Error al seleccionar PDF', error: e);
      if (mounted) {
        // ignore: use_build_context_synchronously
        _showErrorSnackbar(context, 'No se pudo seleccionar el PDF.');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _submit(BuildContext context) async {
    final confirm = await _showSubmitConfirmDialog(context);
    if (!confirm) return;

    final success = await ref
        .read(evidenceSectionNotifierProvider(widget.clubInstanceId).notifier)
        .submit(widget.section.id);

    if (!mounted) return;
    if (success) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Sección enviada a validación exitosamente'),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      // ignore: use_build_context_synchronously
      Navigator.pop(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context, EvidenceFile file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text(
            '¿Estás seguro de que deseas eliminar "${file.fileName}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(evidenceSectionNotifierProvider(widget.clubInstanceId).notifier)
          .deleteFile(
            sectionId: widget.section.id,
            fileId: file.id,
          );
    }
  }

  // ── Dialogs helpers ───────────────────────────────────────────────────────────

  Future<ImageSource?> _showImageSourceDialog(BuildContext context) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.sac.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Seleccionar imagen',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera01,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Cámara'),
              subtitle: const Text('Tomar una foto ahora'),
              onTap: () =>
                  Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Galería'),
              subtitle: const Text('Elegir de la galería de fotos'),
              onTap: () =>
                  Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<bool> _showSubmitConfirmDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a validación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Una vez enviada, no podrás modificar los archivos de esta sección hasta recibir retroalimentación del campo local.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Archivos adjuntos: ${widget.section.files.length}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.secondary,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

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
                fontSize: 11,
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
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Empty files state ─────────────────────────────────────────────────────────

class _EmptyFiles extends StatelessWidget {
  final bool canModify;

  const _EmptyFiles({required this.canModify});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedFiles01,
            size: 48,
            color: c.textTertiary,
          ),
          const SizedBox(height: 12),
          Text(
            canModify
                ? 'Aún no hay archivos. Usa el botón de abajo para subir evidencias.'
                : 'No hay archivos de evidencia para esta sección.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom action bar ──────────────────────────────────────────────────────────

class _BottomActionBar extends StatelessWidget {
  final EvidenceSection section;
  final bool isLoading;
  final VoidCallback onUploadImage;
  final VoidCallback onUploadPdf;
  final VoidCallback onSubmit;

  const _BottomActionBar({
    required this.section,
    required this.isLoading,
    required this.onUploadImage,
    required this.onUploadPdf,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasFiles = section.files.isNotEmpty;
    final canUploadMore = section.remainingSlots > 0;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Slot indicator
          if (canUploadMore)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${section.remainingSlots} de ${section.maxFiles} archivos disponibles',
                style: TextStyle(
                  fontSize: 12,
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Limite de archivos alcanzado (${section.maxFiles}/${section.maxFiles})',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Upload buttons
          if (canUploadMore)
            Row(
              children: [
                Expanded(
                  child: SacButton.outline(
                    text: 'Imagen',
                    icon: HugeIcons.strokeRoundedCamera01,
                    isEnabled: !isLoading,
                    onPressed: isLoading ? null : onUploadImage,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SacButton.outline(
                    text: 'PDF',
                    icon: HugeIcons.strokeRoundedPdf01,
                    isEnabled: !isLoading,
                    onPressed: isLoading ? null : onUploadPdf,
                  ),
                ),
              ],
            ),

          if (canUploadMore) const SizedBox(height: 10),

          // Submit button
          SacButton.primary(
            text: 'Enviar a validación',
            icon: HugeIcons.strokeRoundedSent,
            isEnabled: hasFiles && !isLoading,
            isLoading: isLoading,
            onPressed:
                hasFiles && !isLoading ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
