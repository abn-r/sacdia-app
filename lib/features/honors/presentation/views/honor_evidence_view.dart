import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../validation/domain/entities/validation.dart';
import '../../../validation/presentation/providers/validation_providers.dart';
import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';

/// Evidence & progress screen for an enrolled honor.
///
/// Header color adapts to validation status.
/// Shows: status card, material download, evidence grid, action buttons.
///
/// Integration with validation feature:
/// - Uses [SubmitValidationNotifier] from `features/validation/` for submit
/// - Uses [ValidationEntityType.honor] as entity type
/// - entity_id is the `user_honor_id` (NOT honor_id)
class HonorEvidenceView extends ConsumerStatefulWidget {
  final int honorId;
  final int userHonorId;

  const HonorEvidenceView({
    super.key,
    required this.honorId,
    required this.userHonorId,
  });

  @override
  ConsumerState<HonorEvidenceView> createState() => _HonorEvidenceViewState();
}

class _HonorEvidenceViewState extends ConsumerState<HonorEvidenceView> {
  static const int _maxFiles = 10;
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10 MB

  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    final userHonor = ref.watch(userHonorForHonorProvider(widget.honorId));
    final userHonorsAsync = ref.watch(userHonorsProvider);
    final honorsAsync = ref.watch(allHonorsProvider);

    // Show loading while userHonorsProvider is still fetching
    if (userHonorsAsync.isLoading) {
      return const Scaffold(body: Center(child: SacLoading()));
    }

    // Surface any hard error from userHonorsProvider
    if (userHonorsAsync.hasError) {
      return Scaffold(
        appBar: AppBar(backgroundColor: AppColors.sacRed),
        body: const Center(child: Text('Error al cargar')),
      );
    }

    if (userHonor == null) {
      return const Scaffold(
        body: Center(child: Text('Honor no encontrado')),
      );
    }

    // Find the honor catalog entry for metadata (name, image, materialUrl)
    final honor = honorsAsync.maybeWhen(
      data: (honors) {
        try {
          return honors.firstWhere((h) => h.id == widget.honorId);
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );

    return Stack(
      children: [
        _EvidenceBody(
          userHonor: userHonor,
          honor: honor,
          onSubmit: () => _submitForReview(userHonor),
          onAddEvidence: _showFilePickerOptions,
          onDeleteEvidence: (imageUrl) =>
              _deleteEvidenceFile(userHonor, imageUrl),
          onViewEvidence: (imageUrl) =>
              _openEvidenceFile(imageUrl),
        ),
        if (_isUploading)
          Container(
            color: Colors.black.withAlpha(90),
            child: const Center(child: SacLoading()),
          ),
      ],
    );
  }

  Future<void> _submitForReview(UserHonor userHonor) async {
    final success = await ref.read(submitValidationProvider.notifier).submit(
          entityType: ValidationEntityType.honor,
          entityId: userHonor.id, // user_honor_id, NOT honor_id
        );

    if (success && mounted) {
      // Refresh user honors to reflect new status.
      // userHonorStatsLocalProvider recomputes automatically when
      // userHonorsProvider is invalidated — no explicit invalidation needed.
      ref.invalidate(userHonorsProvider);
      ref.invalidate(userHonorForHonorProvider(widget.honorId));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enviada a revision'),
          backgroundColor: AppColors.sacGreen,
        ),
      );
    }
  }

  void _showFilePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
                color: AppColors.sacGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.sacBlue,
              ),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.sacGreen,
              ),
              title: const Text('Elegir de galeria'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_rounded,
                color: AppColors.sacRed,
              ),
              title: const Text('Seleccionar PDF'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPdf();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromCamera() async {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor != null && userHonor.evidenceCount >= _maxFiles) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      await _uploadFile(File(image.path), image.name);
    }
  }

  Future<void> _pickFromGallery() async {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor != null && userHonor.evidenceCount >= _maxFiles) return;

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    for (final image in images) {
      await _uploadFile(File(image.path), image.name);
    }
  }

  Future<void> _pickPdf() async {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor != null && userHonor.evidenceCount >= _maxFiles) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: true,
    );
    if (result != null) {
      for (final file in result.files) {
        if (file.path != null) {
          await _uploadFile(File(file.path!), file.name);
        }
      }
    }
  }

  Future<void> _uploadFile(File file, String fileName) async {
    final fileSize = await file.length();
    if (fileSize > _maxFileSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fileName excede el limite de 10MB'),
            backgroundColor: AppColors.sacRed,
          ),
        );
      }
      return;
    }

    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No hay sesión activa'),
            backgroundColor: AppColors.sacRed,
          ),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      final dataSource = ref.read(honorsRemoteDataSourceProvider);
      await dataSource.uploadHonorFile(
        userId: userId,
        honorId: widget.honorId,
        file: file,
        fileName: fileName,
      );

      ref.invalidate(userHonorsProvider);
      ref.invalidate(userHonorForHonorProvider(widget.honorId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidencia subida correctamente'),
            backgroundColor: AppColors.sacGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir $fileName'),
            backgroundColor: AppColors.sacRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteEvidenceFile(
      UserHonor userHonor, String imageUrl) async {
    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) return;

    setState(() => _isUploading = true);

    try {
      final updatedImages =
          userHonor.images.where((url) => url != imageUrl).toList();

      final dataSource = ref.read(honorsRemoteDataSourceProvider);
      await dataSource.updateUserHonor(
        userId,
        userHonor.honorId,
        {'images': updatedImages},
      );

      ref.invalidate(userHonorsProvider);
      ref.invalidate(userHonorForHonorProvider(widget.honorId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evidencia eliminada'),
            backgroundColor: AppColors.sacGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar evidencia'),
            backgroundColor: AppColors.sacRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _openEvidenceFile(String url) {
    final lower = url.toLowerCase();
    final isPdf =
        lower.endsWith('.pdf') || lower.contains('/pdf');
    if (isPdf) {
      _launchUrl(url);
    } else {
      SacImageViewer.show(context, imageUrl: url);
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el archivo'),
            backgroundColor: AppColors.sacRed,
          ),
        );
      }
    }
  }
}

// ── Evidence Body ─────────────────────────────────────────────────────────────

class _EvidenceBody extends StatelessWidget {
  final UserHonor userHonor;
  final Honor? honor;
  final VoidCallback onSubmit;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url) onViewEvidence;

  const _EvidenceBody({
    required this.userHonor,
    this.honor,
    required this.onSubmit,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
  });

  Color get _headerColor => userHonor.statusColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: _headerColor,
            foregroundColor: Colors.white,
            title: const Text(
              'Mi especialidad',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: _headerColor,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 16),
                    child: Row(
                      children: [
                        // Honor icon
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(38),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: honor?.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: CachedNetworkImage(
                                    imageUrl: honor!.imageUrl!,
                                    fit: BoxFit.contain,
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.emoji_events_outlined,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.emoji_events_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                honor?.name ??
                                    userHonor.honorName ??
                                    'Especialidad',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              // Status badge pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(51),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  userHonor.statusLabel,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status card
                  _StatusMessageCard(userHonor: userHonor),
                  const SizedBox(height: 20),

                  // Material download (only when URL available)
                  if (honor?.materialUrl != null &&
                      honor!.materialUrl!.isNotEmpty) ...[
                    _MaterialCard(
                      materialUrl: honor!.materialUrl!,
                      onOpen: onViewEvidence,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Evidence section
                  _EvidenceSection(
                    userHonor: userHonor,
                    onAddEvidence: onAddEvidence,
                    onDeleteEvidence: onDeleteEvidence,
                    onViewEvidence: onViewEvidence,
                  ),
                  const SizedBox(height: 24),

                  // Action buttons (status-based)
                  _ActionButtons(
                    userHonor: userHonor,
                    onSubmit: onSubmit,
                    onAddEvidence: onAddEvidence,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Message Card ───────────────────────────────────────────────────────

class _StatusMessageCard extends StatelessWidget {
  final UserHonor userHonor;

  const _StatusMessageCard({required this.userHonor});

  (IconData, String) get _statusContent {
    switch (userHonor.displayStatus) {
      case 'inscripto':
        return (
          Icons.info_outline_rounded,
          'Descarga el material, completa las actividades con tu instructor y subi la evidencia',
        );
      case 'en_progreso':
        return (
          Icons.upload_file_rounded,
          'Tienes evidencia cargada. Cuando estes listo, enviala a revision',
        );
      case 'enviado':
        return (
          Icons.hourglass_top_rounded,
          'Tu evidencia fue enviada. Un coordinador la revisara pronto',
        );
      case 'validado':
        return (
          Icons.check_circle_outline_rounded,
          'Especialidad completada!',
        );
      case 'rechazado':
        return (
          Icons.error_outline_rounded,
          'Tu evidencia fue rechazada: ${userHonor.rejectionReason ?? "Sin motivo especificado"}. Podes corregir y reenviar',
        );
      default:
        return (Icons.info_outline_rounded, '');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, message) = _statusContent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: userHonor.statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: userHonor.statusColor.withAlpha(51),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: userHonor.statusColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: userHonor.statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Material Card ─────────────────────────────────────────────────────────────

class _MaterialCard extends StatelessWidget {
  final String materialUrl;
  final void Function(String url) onOpen;

  const _MaterialCard({
    required this.materialUrl,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onOpen(materialUrl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.sacBlue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Material de estudio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.sacBlack,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Descargar PDF',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.download_rounded,
              color: AppColors.sacBlue,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Evidence Section ──────────────────────────────────────────────────────────

class _EvidenceSection extends StatelessWidget {
  final UserHonor userHonor;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url) onViewEvidence;

  const _EvidenceSection({
    required this.userHonor,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final canEdit = userHonor.canSubmit; // in_progress or rejected

    // Total cells: images + optional add-button cell
    final showAddCell = canEdit && userHonor.evidenceCount < 10;
    final itemCount = userHonor.images.length + (showAddCell ? 1 : 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Evidencia',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.sacBlack,
              ),
            ),
            Text(
              '${userHonor.evidenceCount}/10',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 3-column evidence grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            // Last cell: add-evidence button
            if (index == userHonor.images.length && showAddCell) {
              return _AddEvidenceCell(onTap: onAddEvidence);
            }

            // Evidence thumbnail
            final imageUrl = userHonor.images[index];
            return _EvidenceThumbnail(
              imageUrl: imageUrl,
              canDelete: canEdit,
              onDelete: () => onDeleteEvidence(imageUrl),
              onTap: () => onViewEvidence(imageUrl),
            );
          },
        ),

        // Empty state when no evidence and can't add (e.g. enviado/validado)
        if (itemCount == 0)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.photo_library_outlined,
                  color: Color(0xFF94A3B8),
                  size: 32,
                ),
                SizedBox(height: 8),
                Text(
                  'Sin evidencia cargada',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AddEvidenceCell extends StatelessWidget {
  final VoidCallback onTap;

  const _AddEvidenceCell({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE1E6E7),
            width: 1.5,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.add_rounded,
            color: Color(0xFFCBD5E1),
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _EvidenceThumbnail extends StatelessWidget {
  final String imageUrl;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _EvidenceThumbnail({
    required this.imageUrl,
    required this.canDelete,
    required this.onDelete,
    required this.onTap,
  });

  bool get _isPdf =>
      imageUrl.toLowerCase().endsWith('.pdf') ||
      imageUrl.toLowerCase().contains('/pdf');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: canDelete
          ? () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Eliminar evidencia'),
                  content: const Text(
                    'Estas seguro de que queres eliminar esta evidencia?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.sacRed,
                      ),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
            }
          : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // File content
            if (_isPdf)
              Container(
                color: const Color(0xFFFFF0F0),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: AppColors.sacRed,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.sacRed,
                      ),
                    ),
                  ],
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFFF0F4F5),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFFF0F4F5),
                  child: const Icon(
                    Icons.broken_image_rounded,
                    color: AppColors.sacGrey,
                    size: 24,
                  ),
                ),
              ),

            // Green checkmark overlay for images
            if (!_isPdf)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.sacGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Action Buttons ────────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerWidget {
  final UserHonor userHonor;
  final VoidCallback onSubmit;
  final VoidCallback onAddEvidence;

  const _ActionButtons({
    required this.userHonor,
    required this.onSubmit,
    required this.onAddEvidence,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(submitValidationProvider);

    switch (userHonor.displayStatus) {
      case 'inscripto':
        // No evidence yet — single "Subir evidencia" button
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAddEvidence,
            icon: const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Subir evidencia'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sacBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case 'en_progreso':
        // Has evidence — "Enviar a revision" (primary) + "Subir mas" (outline)
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: submitState.isLoading ? null : onSubmit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sacGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: submitState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Enviar a revision'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onAddEvidence,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Subir mas'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sacBlue,
                  side: const BorderSide(color: AppColors.sacBlue),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        );

      case 'enviado':
        // Under review — no action buttons
        return const SizedBox.shrink();

      case 'validado':
        // Completed — "Ver insignia" navigates to completion screen
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              context.push(
                RouteNames.honorCompletionPath(
                  userHonor.honorId.toString(),
                  userHonor.id.toString(),
                ),
              );
            },
            icon: const Icon(Icons.emoji_events_rounded, size: 18),
            label: const Text('Ver insignia'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sacGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        );

      case 'rechazado':
        // Rejected — "Corregir y reenviar" opens file picker
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onAddEvidence,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sacGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Corregir y reenviar'),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
