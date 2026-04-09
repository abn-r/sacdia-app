import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/utils/honor_category_colors.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../validation/domain/entities/validation.dart';
import '../../../validation/presentation/providers/validation_providers.dart'
    show submitValidationProvider, SubmitValidationState;
import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kScreenPad = 20.0;
const _kSectionGap = 16.0;
const _kHeroHeight = 200.0;

/// Evidence & progress screen for an enrolled honor.
///
/// Minimalist gamified design (Duolingo-inspired) consistent with
/// [HonorDetailView]. Category color drives the hero gradient accent;
/// status is surfaced as a pill badge only.
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

    // Find the honor catalog entry for metadata (name, image, materialUrl).
    // Watching allHonorsProvider triggers the fetch if not already loaded
    // (e.g. when navigating from profile instead of catalog).
    // The evidence view renders immediately with userHonor data;
    // the material card appears once allHonorsProvider resolves.
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
          onViewEvidence: _openEvidenceFile,
          onOpenMaterial: _launchUrl,
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
            content: Text('No hay sesion activa'),
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
    final isPdf = lower.endsWith('.pdf') || lower.contains('/pdf');
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
  final Future<void> Function(String url) onOpenMaterial;

  const _EvidenceBody({
    required this.userHonor,
    this.honor,
    required this.onSubmit,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
    required this.onOpenMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = getCategoryColor(categoryId: honor?.categoryId);

    return Scaffold(
      backgroundColor: context.sac.background,
      body: Stack(
        children: [
          // ── Scrollable content ────────────────────────────────────
          CustomScrollView(
            slivers: [
              // Hero SliverAppBar
              SliverAppBar(
                expandedHeight: _kHeroHeight,
                pinned: true,
                backgroundColor: categoryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                // Category name or "Mi especialidad" as compact title
                title: Text(
                  'Mi especialidad',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: [
                  _StatusPill(status: userHonor.displayStatus),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroSection(
                    honor: honor,
                    userHonor: userHonor,
                    categoryColor: categoryColor,
                  ),
                ),
              ),

              // ── Body cards ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kScreenPad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),

                      // Material download (only when URL available)
                      if (honor?.materialUrl != null &&
                          honor!.materialUrl!.isNotEmpty) ...[
                        _MaterialCard(
                          materialUrl: honor!.materialUrl!,
                          categoryColor: categoryColor,
                          onOpen: onOpenMaterial,
                        ),
                        const SizedBox(height: _kSectionGap),
                      ],

                      // Evidence section card
                      _EvidenceSectionCard(
                        userHonor: userHonor,
                        categoryColor: categoryColor,
                        onAddEvidence: onAddEvidence,
                        onDeleteEvidence: onDeleteEvidence,
                        onViewEvidence: onViewEvidence,
                      ),
                      const SizedBox(height: _kSectionGap),

                      // Rejection card (only when rejected)
                      if (userHonor.displayStatus == 'rechazado') ...[
                        _RejectionCard(
                          reason: userHonor.rejectionReason,
                        ),
                        const SizedBox(height: _kSectionGap),
                      ],

                      // Bottom clearance for floating CTA
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Floating CTA bar ──────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCtaBar(
              userHonor: userHonor,
              categoryColor: categoryColor,
              onSubmit: onSubmit,
              onAddEvidence: onAddEvidence,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Section ───────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  final Honor? honor;
  final UserHonor userHonor;
  final Color categoryColor;

  const _HeroSection({
    required this.honor,
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            categoryColor,
            categoryColor.withValues(alpha: 0.72),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Honor badge image — oval shape, no border
              _HonorBadge(honor: honor),
              const SizedBox(height: 12),

              // Honor name
              Text(
                honor?.name ?? userHonor.honorName ?? 'Especialidad',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Honor Badge ────────────────────────────────────────────────────────────────

class _HonorBadge extends StatelessWidget {
  final Honor? honor;

  const _HonorBadge({required this.honor});

  @override
  Widget build(BuildContext context) {
    // Oval shape: 80w x 62h, no border, subtle shadow
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.elliptical(40, 31)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.elliptical(40, 31)),
        child: SizedBox(
          width: 80,
          height: 62,
          child: honor?.imageUrl != null && honor!.imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: honor!.imageUrl!,
                  fit: BoxFit.contain,
                  memCacheWidth: 240,
                  memCacheHeight: 186,
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.white.withValues(alpha: 0.20),
                    child: const Icon(
                      Icons.emoji_events_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                )
              : Container(
                  color: Colors.white.withValues(alpha: 0.20),
                  child: const Icon(
                    Icons.emoji_events_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
        ),
      ),
    );
  }
}

// ── Status Pill ────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  Color _bgColor() {
    switch (status) {
      case 'validado':
        return AppColors.sacGreen;
      case 'enviado':
        return AppColors.sacYellow;
      case 'rechazado':
        return AppColors.sacRed;
      case 'en_progreso':
        return Colors.white.withValues(alpha: 0.30);
      default:
        return Colors.white.withValues(alpha: 0.25);
    }
  }

  String _label() {
    switch (status) {
      case 'validado':
        return 'Validada';
      case 'enviado':
        return 'En revision';
      case 'en_progreso':
        return 'En progreso';
      case 'rechazado':
        return 'Rechazada';
      default:
        return 'Inscrita';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Material Card ─────────────────────────────────────────────────────────────

class _MaterialCard extends StatelessWidget {
  final String materialUrl;
  final Color categoryColor;
  final Future<void> Function(String url) onOpen;

  const _MaterialCard({
    required this.materialUrl,
    required this.categoryColor,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onOpen(materialUrl),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.sac.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: context.sac.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // PDF icon in colored circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf_rounded,
                color: categoryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Material de estudio',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.sac.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Descargar PDF',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.sac.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.download_rounded,
              color: categoryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Evidence Section Card ─────────────────────────────────────────────────────

class _EvidenceSectionCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url) onViewEvidence;

  const _EvidenceSectionCard({
    required this.userHonor,
    required this.categoryColor,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
  });

  @override
  Widget build(BuildContext context) {
    // canEdit: user may add or delete evidence (in_progress or rejected)
    final canEdit = userHonor.canSubmit;
    final showAddCell = canEdit && userHonor.evidenceCount < 10;
    final hasEvidence = userHonor.images.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Evidencia',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.sac.text,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${userHonor.evidenceCount}/10',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Grid or empty state
          if (!hasEvidence && !showAddCell)
            _EmptyEvidenceState(
              categoryColor: categoryColor,
              canAdd: false,
              onAdd: onAddEvidence,
            )
          else if (!hasEvidence && showAddCell)
            _EmptyEvidenceState(
              categoryColor: categoryColor,
              canAdd: true,
              onAdd: onAddEvidence,
            )
          else
            _EvidenceGrid(
              images: userHonor.images,
              showAddCell: showAddCell,
              canDelete: canEdit,
              categoryColor: categoryColor,
              onAddEvidence: onAddEvidence,
              onDeleteEvidence: onDeleteEvidence,
              onViewEvidence: onViewEvidence,
            ),
        ],
      ),
    );
  }
}

// ── Empty Evidence State ───────────────────────────────────────────────────────

class _EmptyEvidenceState extends StatelessWidget {
  final Color categoryColor;
  final bool canAdd;
  final VoidCallback onAdd;

  const _EmptyEvidenceState({
    required this.categoryColor,
    required this.canAdd,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.sac.borderLight,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.photo_library_outlined,
            color: context.sac.textTertiary,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            'Subi tu primera evidencia',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.sac.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fotos, imagenes o documentos PDF',
            style: TextStyle(
              fontSize: 12,
              color: context.sac.textTertiary,
            ),
          ),
          if (canAdd) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Agregar evidencia',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Evidence Grid ──────────────────────────────────────────────────────────────

class _EvidenceGrid extends StatelessWidget {
  final List<String> images;
  final bool showAddCell;
  final bool canDelete;
  final Color categoryColor;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url) onViewEvidence;

  const _EvidenceGrid({
    required this.images,
    required this.showAddCell,
    required this.canDelete,
    required this.categoryColor,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = images.length + (showAddCell ? 1 : 0);

    return GridView.builder(
      // shrinkWrap OK: lives inside SliverToBoxAdapter > Column (non-scrollable).
      // Item count is bounded by the evidence images a user uploads per honor.
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
        if (index == images.length && showAddCell) {
          return _AddEvidenceCell(
            categoryColor: categoryColor,
            onTap: onAddEvidence,
          );
        }

        final imageUrl = images[index];
        return _EvidenceThumbnail(
          imageUrl: imageUrl,
          canDelete: canDelete,
          onDelete: () => onDeleteEvidence(imageUrl),
          onTap: () => onViewEvidence(imageUrl),
        );
      },
    );
  }
}

// ── Add Evidence Cell ──────────────────────────────────────────────────────────

class _AddEvidenceCell extends StatelessWidget {
  final Color categoryColor;
  final VoidCallback onTap;

  const _AddEvidenceCell({
    required this.categoryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: categoryColor.withValues(alpha: 0.40),
            width: 1.5,
            // Dashed border via CustomPainter is complex; a solid colored
            // border with low-opacity fill communicates "add" clearly.
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_rounded,
              color: categoryColor,
              size: 28,
            ),
            const SizedBox(height: 2),
            Text(
              'Agregar',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: categoryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Evidence Thumbnail ─────────────────────────────────────────────────────────

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
              HapticFeedback.mediumImpact();
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
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // File content
            if (_isPdf)
              Container(
                color: AppColors.sacRed.withAlpha(20),
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
                placeholder: (_, __) => Builder(
                  builder: (context) => Container(
                    color: context.sac.surfaceVariant,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Builder(
                  builder: (context) => Container(
                    color: context.sac.surfaceVariant,
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: context.sac.textTertiary,
                      size: 24,
                    ),
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

            // Long-press hint overlay (subtle gradient at bottom)
            if (canDelete)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Rejection Card ────────────────────────────────────────────────────────────

class _RejectionCard extends StatelessWidget {
  final String? reason;

  const _RejectionCard({this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sacRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.sacRed.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.sacRed,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evidencia rechazada',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sacRed,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason?.isNotEmpty == true
                      ? reason!
                      : 'Sin motivo especificado',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.sacRed,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Podes corregir y reenviar',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.sacRed.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom CTA Bar ────────────────────────────────────────────────────────────

class _BottomCtaBar extends ConsumerWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final VoidCallback onSubmit;
  final VoidCallback onAddEvidence;

  const _BottomCtaBar({
    required this.userHonor,
    required this.categoryColor,
    required this.onSubmit,
    required this.onAddEvidence,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submitState = ref.watch(submitValidationProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: _buildCtaButton(context, submitState),
        ),
      ),
    );
  }

  Widget _buildCtaButton(
      BuildContext context, SubmitValidationState submitState) {
    switch (userHonor.displayStatus) {
      case 'inscrito':
        // No evidence yet — prompt to upload
        return _CtaButton(
          label: 'Subir evidencia',
          icon: Icons.upload_rounded,
          color: categoryColor,
          onPressed: onAddEvidence,
        );

      case 'en_progreso':
        // Has evidence, not submitted — send for review
        return _CtaButton(
          label: 'Enviar a revision',
          icon: Icons.send_rounded,
          color: categoryColor,
          isLoading: submitState.isLoading,
          onPressed: submitState.isLoading ? null : onSubmit,
        );

      case 'enviado':
        // Under review — disabled
        return _CtaButton(
          label: 'Enviada — en revision',
          icon: Icons.hourglass_top_rounded,
          color: AppColors.sacGrey,
          onPressed: null,
        );

      case 'validado':
        // Completed — navigate to completion screen
        return Builder(
          builder: (context) => _CtaButton(
            label: 'Especialidad completada',
            icon: Icons.emoji_events_rounded,
            color: AppColors.sacGreen,
            onPressed: () {
              context.push(
                RouteNames.honorCompletionPath(
                  userHonor.honorId.toString(),
                  userHonor.id.toString(),
                ),
              );
            },
          ),
        );

      case 'rechazado':
        // Rejected — correct and resubmit
        return _CtaButton(
          label: 'Corregir y reenviar',
          icon: Icons.refresh_rounded,
          color: categoryColor,
          onPressed: onAddEvidence,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── CTA Button ────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _CtaButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isDisabled ? AppColors.sacGrey : color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.sacGrey,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.70),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
