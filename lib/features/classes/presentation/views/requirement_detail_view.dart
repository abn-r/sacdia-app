import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/requirement_evidence.dart';
import '../providers/classes_providers.dart';
import '../widgets/requirement_evidence_grid.dart';
import '../widgets/requirement_status_badge.dart';
import '../widgets/requirement_status_timeline.dart';

/// Vista de detalle de un requerimiento de clase progresiva.
///
/// Permite al usuario:
/// - Ver el estado actual y la linea de tiempo del requerimiento.
/// - Ver los archivos de evidencia subidos.
/// - Subir nuevos archivos cuando el requerimiento esta pendiente.
/// - Eliminar archivos en estado pendiente.
/// - Enviar el requerimiento a validacion.
///
/// Sigue el patron identico al EvidenceSectionDetailView de carpeta_evidencias.
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

class _RequirementDetailViewState
    extends ConsumerState<RequirementDetailView> {
  final _picker = ImagePicker();

  bool _isUploading = false;

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
    }).valueOrNull ?? widget.requirement;
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
    final canModify = requirement.status == RequirementStatus.pendiente;

    // Mostrar snackbar cuando hay error
    ref.listen(
      requirementNotifierProvider(widget.classId),
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
          requirement.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          overflow: TextOverflow.ellipsis,
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
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta card con descripcion y metricas
                    _RequirementMetaCard(requirement: requirement),

                    const SizedBox(height: 16),

                    // Especialidad vinculada (si aplica)
                    if (requirement.type == RequirementType.honor &&
                        requirement.linkedHonorName != null)
                      _LinkedHonorSection(
                          requirement: requirement),

                    // Timeline de estado
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: Text(
                        'Flujo de estado',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      child: RequirementStatusTimeline(
                        currentStatus: requirement.status,
                        submittedByName:
                            requirement.submittedByName,
                        submittedAt: requirement.submittedAt,
                        validatedByName:
                            requirement.validatedByName,
                        validatedAt: requirement.validatedAt,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Archivos de evidencia
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                          if (canModify)
                            Text(
                              '${requirement.files.length} / ${requirement.maxFiles}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: requirement.remainingSlots == 0
                                    ? AppColors.error
                                    : c.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (requirement.files.isEmpty)
                      _EmptyFiles(canModify: canModify)
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        child: RequirementEvidenceGrid(
                          files: requirement.files,
                          canDelete: canModify,
                          onDelete: canModify
                              ? (file) =>
                                  _confirmDelete(context, file)
                              : null,
                        ),
                      ),

                    // Espacio para los botones inferiores
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
      bottomNavigationBar: canModify
          ? _BottomActionBar(
              requirement: requirement,
              isLoading: isLoading,
              onUploadImage: () => _pickImage(context, requirement),
              onUploadPdf: () => _pickPdf(context, requirement),
              onSubmit: () => _submit(context, requirement),
            )
          : null,
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────────────

  /// Construye un nombre de archivo descriptivo para el backend/storage.
  ///
  /// Genera nombre con índice explícito (para batch uploads).
  String _buildFileNameWithIndex(ClassRequirement requirement, String originalName, int index) {
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
    }).valueOrNull ?? 'modulo';
  }

  /// Extrae las iniciales del usuario autenticado.
  String _resolveUserInitials() {
    final user = ref.read(authNotifierProvider).valueOrNull;
    if (user?.name == null || user!.name!.isEmpty) return 'NN';
    final parts = user.name!.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first.substring(0, parts.first.length.clamp(0, 2)).toUpperCase();
  }

  Future<void> _pickImage(BuildContext context, ClassRequirement requirement) async {
    if (requirement.remainingSlots == 0) {
      _showErrorSnackbar(
          context, 'Has alcanzado el limite de archivos para este requerimiento.');
      return;
    }

    final source = await _showImageSourceDialog(context);
    if (source == null) return;

    try {
      // Camera: single image. Gallery: multi-select.
      final List<XFile> pickedFiles;
      if (source == ImageSource.camera) {
        final single = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        pickedFiles = single != null ? [single] : [];
      } else {
        pickedFiles = await _picker.pickMultiImage(
          imageQuality: 85,
          maxWidth: 2048,
          maxHeight: 2048,
        );
      }

      if (pickedFiles.isEmpty || !mounted) return;

      // Respect remaining slots
      final slots = requirement.remainingSlots;
      final toUpload = pickedFiles.length > slots
          ? pickedFiles.sublist(0, slots)
          : pickedFiles;

      if (toUpload.length < pickedFiles.length && mounted) {
        _showErrorSnackbar(
          context,
          'Solo se subiran ${toUpload.length} de ${pickedFiles.length} imagenes (limite alcanzado).',
        );
      }

      setState(() => _isUploading = true);

      var uploadedCount = requirement.files.length;
      for (final picked in toUpload) {
        if (!mounted) break;
        uploadedCount++;

        final mimeType = picked.name.toLowerCase().endsWith('.png')
            ? 'image/png'
            : 'image/jpeg';
        final ext = mimeType == 'image/png' ? 'png' : 'jpg';
        final namedFile = XFile(
          picked.path,
          name: _buildFileNameWithIndex(requirement, 'imagen.$ext', uploadedCount),
          mimeType: mimeType,
        );

        await ref
            .read(requirementNotifierProvider(widget.classId).notifier)
            .uploadFile(
              requirementId: requirement.id,
              pickedFile: namedFile,
              mimeType: mimeType,
            );
      }
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

  Future<void> _pickPdf(BuildContext context, ClassRequirement requirement) async {
    if (requirement.remainingSlots == 0) {
      _showErrorSnackbar(
          context, 'Has alcanzado el limite de archivos para este requerimiento.');
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty || !mounted) return;

      // Respect remaining slots
      final slots = requirement.remainingSlots;
      final filesToUpload = result.files.length > slots
          ? result.files.sublist(0, slots)
          : result.files;

      if (filesToUpload.length < result.files.length && mounted) {
        _showErrorSnackbar(
          context,
          'Solo se subiran ${filesToUpload.length} de ${result.files.length} PDFs (limite alcanzado).',
        );
      }

      setState(() => _isUploading = true);

      var uploadedCount = requirement.files.length;
      for (final platformFile in filesToUpload) {
        if (!mounted) break;
        if (platformFile.path == null) continue;
        uploadedCount++;

        final picked = XFile(
          platformFile.path!,
          name: _buildFileNameWithIndex(requirement, 'documento.pdf', uploadedCount),
          mimeType: 'application/pdf',
        );

        await ref
            .read(requirementNotifierProvider(widget.classId).notifier)
            .uploadFile(
              requirementId: requirement.id,
              pickedFile: picked,
              mimeType: 'application/pdf',
            );
      }
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

  Future<void> _submit(BuildContext context, ClassRequirement requirement) async {
    final confirm = await _showSubmitConfirmDialog(context, requirement);
    if (!confirm) return;

    final success = await ref
        .read(requirementNotifierProvider(widget.classId).notifier)
        .submit(requirement.id);

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
              Expanded(
                child: Text('Requerimiento enviado a validacion exitosamente'),
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
  }

  Future<void> _confirmDelete(
      BuildContext context, RequirementEvidence file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar archivo'),
        content: Text(
            '¿Estas seguro de que deseas eliminar "${file.fileName}"? Esta accion no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref
          .read(requirementNotifierProvider(widget.classId).notifier)
          .deleteFile(
            requirementId: widget.requirement.id,
            fileId: file.id,
          );
    }
  }

  // ── Dialog helpers ────────────────────────────────────────────────────────────

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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCamera01,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
              ),
              title: const Text('Camara'),
              subtitle: const Text('Tomar una foto ahora'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedImage01,
                    size: 22,
                    color: AppColors.primary,
                  ),
                ),
              ),
              title: const Text('Galeria'),
              subtitle: const Text('Elegir de la galeria de fotos'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<bool> _showSubmitConfirmDialog(BuildContext context, ClassRequirement requirement) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar a validacion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Una vez enviado, no podras modificar los archivos de este requerimiento hasta recibir retroalimentacion del lider.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Archivos adjuntos: ${requirement.files.length}',
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
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
            children: [
              _MetaItem(
                icon: HugeIcons.strokeRoundedStar,
                label: 'Puntos',
                value: '${requirement.pointValue} pts',
                color: AppColors.accent,
                context: context,
              ),
              const SizedBox(width: 24),
              _MetaItem(
                icon: HugeIcons.strokeRoundedFiles01,
                label: 'Limite archivos',
                value: '${requirement.maxFiles}',
                color: c.textSecondary,
                context: context,
              ),
              const SizedBox(width: 24),
              _MetaItem(
                icon: HugeIcons.strokeRoundedTag01,
                label: 'Tipo',
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
        return 'Especialidad';
      case RequirementType.service:
        return 'Servicio';
      case RequirementType.general:
        return 'General';
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
                  'Especialidad requerida',
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
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isCompleted ? 'Completada' : 'Pendiente',
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
                ? 'Aun no hay archivos. Usa el boton de abajo para subir evidencias.'
                : 'No hay archivos de evidencia para este requerimiento.',
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
  final ClassRequirement requirement;
  final bool isLoading;
  final VoidCallback onUploadImage;
  final VoidCallback onUploadPdf;
  final VoidCallback onSubmit;

  const _BottomActionBar({
    required this.requirement,
    required this.isLoading,
    required this.onUploadImage,
    required this.onUploadPdf,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasFiles = requirement.files.isNotEmpty;
    final canUploadMore = requirement.remainingSlots > 0;

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
            color: c.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Indicador de slots
          if (canUploadMore)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                '${requirement.remainingSlots} de ${requirement.maxFiles} archivos disponibles',
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
                'Limite de archivos alcanzado (${requirement.maxFiles}/${requirement.maxFiles})',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // Botones de subida
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

          // Boton enviar a validacion
          SacButton.primary(
            text: 'Enviar a validacion',
            icon: HugeIcons.strokeRoundedSent,
            isEnabled: hasFiles && !isLoading,
            isLoading: isLoading,
            onPressed: hasFiles && !isLoading ? onSubmit : null,
          ),
        ],
      ),
    );
  }
}
