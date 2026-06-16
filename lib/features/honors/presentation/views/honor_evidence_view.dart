import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/staged_file.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/upload_progress_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/honor_category_palette.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../validation/domain/entities/validation.dart';
import '../../../validation/presentation/providers/validation_providers.dart'
    show submitValidationProvider, SubmitValidationState;
import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';
import '../widgets/honor_badge_image.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

const _kScreenPad = 20.0;
const _kSectionGap = 16.0;
const _kHeroHeight = 200.0;

enum _ExternalUploadKind { completedFormat, generalEvidence }

bool _isLightColor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.light;
}

Color _paintColorForCategory(Color categoryColor, Color categoryAccentColor) {
  return _isLightColor(categoryColor) ? categoryAccentColor : categoryColor;
}

Color _heroForegroundColor(BuildContext context, Color categoryColor) {
  return _isLightColor(categoryColor) ? context.sac.text : Colors.white;
}

Color _heroOverlayColor(BuildContext context, Color categoryColor) {
  return _isLightColor(categoryColor)
      ? context.sac.surfaceVariant.withValues(alpha: 0.85)
      : Colors.white.withValues(alpha: 0.20);
}

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
        appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: sacAutoBackButton(context),
            backgroundColor: AppColors.error),
        body: Center(child: Text('honors.evidence.error_load'.tr())),
      );
    }

    if (userHonor == null) {
      return Scaffold(
        body: Center(child: Text('honors.evidence.not_found'.tr())),
      );
    }

    if (userHonor.completionMode != HonorCompletionMode.external) {
      return _ModeGuardScaffold(
        title: 'honors.evidence.mode_guard_title'.tr(),
        message: userHonor.completionMode == HonorCompletionMode.inApp
            ? 'honors.evidence.mode_guard_in_app'.tr()
            : 'honors.evidence.mode_guard_undecided'.tr(),
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
          onUploadCompletedFormat: () => _showFilePickerOptions(
            kind: _ExternalUploadKind.completedFormat,
          ),
          onAddEvidence: () => _showFilePickerOptions(
            kind: _ExternalUploadKind.generalEvidence,
          ),
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
        SnackBar(
          content: Text('honors.evidence.sent_review'.tr()),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  void _showFilePickerOptions({required _ExternalUploadKind kind}) {
    final isCompletedFormat = kind == _ExternalUploadKind.completedFormat;

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
                color: AppColors.pendingColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            if (!isCompletedFormat) ...[
              ListTile(
                leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera01,
                  color: AppColors.info,
                ),
                title: Text('honors.evidence.pick_camera'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  color: AppColors.success,
                ),
                title: Text('honors.evidence.pick_gallery'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickFromGallery();
                },
              ),
            ],
            if (isCompletedFormat)
              ListTile(
                leading: const HugeIcon(
                  icon: HugeIcons.strokeRoundedPdf01,
                  color: AppColors.error,
                ),
                title: Text('honors.evidence.pick_completed_format'.tr()),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickCompletedFormat();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String _buildEvidenceFileName(String originalName, int index) {
    final extension = originalName.contains('.')
        ? originalName.split('.').last.toLowerCase()
        : 'bin';
    final displayIndex = index.toString().padLeft(2, '0');
    return 'Evidencia $displayIndex.$extension';
  }

  int _nextEvidenceIndex([int offset = 0]) {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    return (userHonor?.generalEvidenceCount ?? 0) + offset + 1;
  }

  Future<void> _pickFromCamera() async {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor != null && userHonor.generalEvidenceCount >= _maxFiles) {
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image != null) {
      await _uploadPickedFiles([
        StagedFile.local(
          localPath: image.path,
          name: _buildEvidenceFileName(image.name, _nextEvidenceIndex()),
          mimeType: 'image/jpeg',
        ),
      ]);
    }
  }

  Future<void> _pickFromGallery() async {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor != null && userHonor.generalEvidenceCount >= _maxFiles) {
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    await _uploadPickedFiles(
      images
          .asMap()
          .entries
          .map(
            (entry) => StagedFile.local(
              localPath: entry.value.path,
              name: _buildEvidenceFileName(
                entry.value.name,
                _nextEvidenceIndex(entry.key),
              ),
              mimeType: 'image/jpeg',
            ),
          )
          .toList(),
    );
  }

  Future<void> _pickCompletedFormat() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    final pickedFile = result?.files.single;
    if (pickedFile?.path == null) return;

    await _uploadPickedFiles(
      [
        StagedFile.local(
          localPath: pickedFile!.path!,
          name: pickedFile.name,
          mimeType: 'application/pdf',
        ),
      ],
      uploadField: HonorFileUploadField.document,
      countsAgainstGeneralCap: false,
    );
  }

  Future<void> _uploadPickedFiles(
    List<StagedFile> pickedFiles, {
    HonorFileUploadField uploadField = HonorFileUploadField.images,
    bool countsAgainstGeneralCap = true,
  }) async {
    if (pickedFiles.isEmpty) return;

    final validFiles = <StagedFile>[];
    for (final pickedFile in pickedFiles) {
      final localPath = pickedFile.localPath;
      if (localPath == null) continue;

      final fileSize = await File(localPath).length();
      if (fileSize > _maxFileSizeBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('honors.evidence.file_size_error'
                  .tr(namedArgs: {'name': pickedFile.name})),
              backgroundColor: AppColors.error,
            ),
          );
        }
        continue;
      }

      validFiles.add(pickedFile);
    }

    if (validFiles.isEmpty) return;

    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    final availableSlots = _maxFiles - (userHonor?.generalEvidenceCount ?? 0);
    if (countsAgainstGeneralCap && availableSlots <= 0) return;

    final queuedFiles = countsAgainstGeneralCap
        ? validFiles.take(availableSlots).toList()
        : validFiles.take(1).toList();
    if (!mounted) return;

    await _showUploadProgress(queuedFiles, uploadField: uploadField);
  }

  Future<void> _showUploadProgress(
    List<StagedFile> initialFiles, {
    HonorFileUploadField uploadField = HonorFileUploadField.images,
  }) async {
    var queueFiles = initialFiles;
    var shouldRetry = true;
    var completedAny = false;

    while (shouldRetry && mounted) {
      shouldRetry = false;

      final streamController = StreamController<List<StagedFile>>.broadcast();
      final sheetResultFuture = showUploadProgressSheet(
        context: context,
        initialFiles: queueFiles,
        uploadStream: streamController.stream,
      );

      streamController.add(queueFiles);

      for (final file in List<StagedFile>.from(queueFiles)) {
        if (file.status != StagedFileStatus.local) continue;

        queueFiles = _updateQueuedFile(
          queueFiles,
          file.id,
          StagedFileStatus.uploading,
          uploadProgress: 0,
        );
        streamController.add(queueFiles);

        try {
          await _uploadQueuedFile(file, uploadField: uploadField);
          completedAny = true;
          queueFiles = _updateQueuedFile(
            queueFiles,
            file.id,
            StagedFileStatus.completed,
            uploadProgress: 1,
          );
        } catch (error) {
          queueFiles = _updateQueuedFile(
            queueFiles,
            file.id,
            StagedFileStatus.error,
            errorMessage: error.toString(),
          );
        }

        streamController.add(queueFiles);
      }

      final sheetResult = await sheetResultFuture;
      await streamController.close();

      if (!mounted) return;

      switch (sheetResult) {
        case UploadSheetResult.retry:
          queueFiles = queueFiles.map((file) {
            if (file.status == StagedFileStatus.error) {
              return file.copyWith(
                status: StagedFileStatus.local,
                uploadProgress: 0,
                errorMessage: null,
              );
            }
            return file;
          }).toList();
          shouldRetry = true;
          break;
        case UploadSheetResult.continueSubmit:
        case UploadSheetResult.continuePartial:
        case UploadSheetResult.cancelled:
        case null:
          shouldRetry = false;
          break;
      }
    }

    if (completedAny) {
      ref
          .read(honorEvidenceActionsNotifierProvider.notifier)
          .invalidateHonorEvidence(widget.honorId);
    }
  }

  List<StagedFile> _updateQueuedFile(
    List<StagedFile> files,
    String fileId,
    StagedFileStatus status, {
    double? uploadProgress,
    String? errorMessage,
  }) {
    return files.map((file) {
      if (file.id != fileId) return file;
      return file.copyWith(
        status: status,
        uploadProgress: uploadProgress ?? file.uploadProgress,
        errorMessage: errorMessage,
      );
    }).toList();
  }

  Future<void> _uploadQueuedFile(
    StagedFile stagedFile, {
    HonorFileUploadField uploadField = HonorFileUploadField.images,
  }) async {
    final localPath = stagedFile.localPath;
    if (localPath == null) return;

    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('honors.evidence.no_session'.tr()),
            backgroundColor: AppColors.error,
          ),
        );
      }
      throw StateError('No active session');
    }

    final success = await ref
        .read(honorEvidenceActionsNotifierProvider.notifier)
        .uploadFile(
          userId: userId,
          honorId: widget.honorId,
          file: File(localPath),
          fileName: stagedFile.name,
          uploadField: uploadField,
          skipInvalidation: true,
        );

    if (!success) {
      throw Exception('honors.evidence.upload_error'
          .tr(namedArgs: {'name': stagedFile.name}));
    }
  }

  Future<void> _deleteEvidenceFile(UserHonor userHonor, String imageUrl) async {
    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) return;

    setState(() => _isUploading = true);

    try {
      final success = await ref
          .read(honorEvidenceActionsNotifierProvider.notifier)
          .deleteEvidenceFile(
            userId: userId,
            userHonor: userHonor,
            imageUrl: imageUrl,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'honors.evidence.delete_success'.tr()
                : 'honors.evidence.delete_error'.tr()),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('honors.evidence.delete_error'.tr()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _openEvidenceFile(
    String url,
    List<String> imageUrls,
    int initialIndex,
  ) {
    final lower = url.toLowerCase();
    final isPdf = lower.endsWith('.pdf') || lower.contains('/pdf');
    if (isPdf) {
      _launchUrl(url);
    } else {
      SacImageViewer.show(
        context,
        imageUrl: url,
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      );
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
          SnackBar(
            content: Text('honors.evidence.open_error'.tr()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}

class _ModeGuardScaffold extends StatelessWidget {
  final String title;
  final String message;

  const _ModeGuardScaffold({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        backgroundColor: AppColors.lightText,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedRoute01,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.sac.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.pop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: Text('honors.evidence.mode_guard_back'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Evidence Body ─────────────────────────────────────────────────────────────

class _EvidenceBody extends StatelessWidget {
  final UserHonor userHonor;
  final Honor? honor;
  final VoidCallback onSubmit;
  final VoidCallback onUploadCompletedFormat;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url, List<String> imageUrls, int initialIndex)
      onViewEvidence;
  final Future<void> Function(String url) onOpenMaterial;

  const _EvidenceBody({
    required this.userHonor,
    this.honor,
    required this.onSubmit,
    required this.onUploadCompletedFormat,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
    required this.onOpenMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = getCategoryColor(
      categoryId: honor?.categoryId ?? userHonor.honorCategoryId,
      categoryName: honor?.categoryName ?? userHonor.honorCategoryName,
    );
    final categoryAccentColor = getCategoryAccentColor(
      categoryId: honor?.categoryId ?? userHonor.honorCategoryId,
      categoryName: honor?.categoryName ?? userHonor.honorCategoryName,
    );
    final categoryPaintColor =
        _paintColorForCategory(categoryColor, categoryAccentColor);
    final heroForegroundColor = _heroForegroundColor(context, categoryColor);
    final heroOverlayColor = _heroOverlayColor(context, categoryColor);

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
                foregroundColor: heroForegroundColor,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: heroOverlayColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: heroForegroundColor,
                      size: 22,
                    ),
                  ),
                ),
                // Category name or "Mi especialidad" as compact title
                title: Text(
                  'honors.evidence.my_honor_title'.tr(),
                  style: TextStyle(
                    color: heroForegroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: [
                  _StatusPill(
                    status: userHonor.displayStatus,
                    defaultBackgroundColor: heroOverlayColor,
                    defaultForegroundColor: heroForegroundColor,
                  ),
                  const SizedBox(width: 12),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroSection(
                    honor: honor,
                    userHonor: userHonor,
                    categoryColor: categoryColor,
                    foregroundColor: heroForegroundColor,
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
                          categoryColor: categoryPaintColor,
                          onOpen: onOpenMaterial,
                        ),
                        const SizedBox(height: _kSectionGap),
                      ],

                      _CompletedFormatCard(
                        userHonor: userHonor,
                        categoryColor: categoryPaintColor,
                        onUploadCompletedFormat: onUploadCompletedFormat,
                        onOpenDocument: onOpenMaterial,
                      ),
                      const SizedBox(height: _kSectionGap),

                      // Evidence section card
                      _EvidenceSectionCard(
                        userHonor: userHonor,
                        categoryColor: categoryPaintColor,
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
              categoryColor: categoryPaintColor,
              onSubmit: onSubmit,
              onUploadCompletedFormat: onUploadCompletedFormat,
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
  final Color foregroundColor;

  const _HeroSection({
    required this.honor,
    required this.userHonor,
    required this.categoryColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _heroForegroundColor(context, categoryColor);

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
              _HonorBadge(
                honor: honor,
                foregroundColor: foregroundColor,
                backgroundColor: _heroOverlayColor(context, categoryColor),
              ),
              const SizedBox(height: 12),

              // Honor name
              Text(
                honor?.name ??
                    userHonor.honorName ??
                    'honors.evidence.honor_fallback'.tr(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foregroundColor,
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
  final Color foregroundColor;
  final Color backgroundColor;

  const _HonorBadge({
    required this.honor,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return HonorBadgeImage(
      imageUrl: honor?.imageUrl,
      width: 80,
      height: 68,
      padding: const EdgeInsets.all(2),
      memCacheWidth: 240,
      memCacheHeight: 204,
      fallbackColor: foregroundColor,
      fallbackBackgroundColor: backgroundColor,
      fallbackIconSize: 22,
      fallbackBorderRadius: BorderRadius.circular(14),
    );
  }
}

// ── Status Pill ────────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String status;
  final Color defaultBackgroundColor;
  final Color defaultForegroundColor;

  const _StatusPill({
    required this.status,
    required this.defaultBackgroundColor,
    required this.defaultForegroundColor,
  });

  Color _bgColor() {
    switch (status) {
      case 'validado':
        return AppColors.success;
      case 'enviado':
        return AppColors.accent;
      case 'rechazado':
        return AppColors.error;
      case 'en_progreso':
      default:
        return defaultBackgroundColor;
    }
  }

  Color _fgColor() {
    switch (status) {
      case 'validado':
      case 'enviado':
      case 'rechazado':
        return Colors.white;
      default:
        return defaultForegroundColor;
    }
  }

  String _label() {
    switch (status) {
      case 'validado':
        return 'honors.evidence.status_validated'.tr();
      case 'enviado':
        return 'honors.evidence.status_sent'.tr();
      case 'en_progreso':
        return 'honors.evidence.status_in_progress'.tr();
      case 'rechazado':
        return 'honors.evidence.status_rejected'.tr();
      default:
        return 'honors.evidence.status_enrolled'.tr();
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
        style: TextStyle(
          color: _fgColor(),
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
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedPdf01,
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
                    'honors.evidence.material_title'.tr(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.sac.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'honors.evidence.material_subtitle'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.sac.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedDownload01,
              color: categoryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Completed Format Card ────────────────────────────────────────────────────

class _CompletedFormatCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final VoidCallback onUploadCompletedFormat;
  final Future<void> Function(String url) onOpenDocument;

  const _CompletedFormatCard({
    required this.userHonor,
    required this.categoryColor,
    required this.onUploadCompletedFormat,
    required this.onOpenDocument,
  });

  @override
  Widget build(BuildContext context) {
    final hasDocument = userHonor.hasCompletedFormat;

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
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (hasDocument ? AppColors.success : categoryColor)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: HugeIcon(
                  icon: hasDocument
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : HugeIcons.strokeRoundedPdf01,
                  color: hasDocument ? AppColors.success : categoryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'honors.evidence.completed_format_title'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.sac.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      hasDocument
                          ? 'honors.evidence.completed_format_uploaded'.tr()
                          : 'honors.evidence.completed_format_missing'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.sac.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUploadCompletedFormat,
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedUpload01,
                    size: 18,
                  ),
                  label: Text(hasDocument
                      ? 'honors.evidence.replace_completed_format'.tr()
                      : 'honors.evidence.upload_completed_format'.tr()),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: categoryColor,
                    side: BorderSide(color: categoryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (hasDocument) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  onPressed: () => onOpenDocument(userHonor.document!),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedView,
                    color: categoryColor,
                    size: 20,
                  ),
                  tooltip: 'honors.evidence.open_completed_format'.tr(),
                ),
              ],
            ],
          ),
        ],
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
  final void Function(String url, List<String> imageUrls, int initialIndex)
      onViewEvidence;

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
    final showAddCell = canEdit && userHonor.generalEvidenceCount < 10;
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
                'honors.evidence.general_section_title'.tr(),
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
                  '${userHonor.generalEvidenceCount}/10',
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
    final foregroundColor = _heroForegroundColor(context, categoryColor);

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
          HugeIcon(
            icon: HugeIcons.strokeRoundedImage01,
            color: context.sac.textTertiary,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            'honors.evidence.general_empty_first'.tr(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.sac.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'honors.evidence.general_empty_subtitle'.tr(),
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      color: foregroundColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'honors.evidence.add_button'.tr(),
                      style: TextStyle(
                        color: foregroundColor,
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
  final void Function(String url, List<String> imageUrls, int initialIndex)
      onViewEvidence;

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
          onTap: () {
            final carouselImages = images.where((url) {
              final lower = url.toLowerCase();
              return !lower.endsWith('.pdf') && !lower.contains('/pdf');
            }).toList();
            final initialIndex = carouselImages.indexOf(imageUrl);
            onViewEvidence(
              imageUrl,
              carouselImages,
              initialIndex < 0 ? 0 : initialIndex,
            );
          },
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
            HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              color: categoryColor,
              size: 28,
            ),
            const SizedBox(height: 2),
            Text(
              'honors.evidence.add_cell_label'.tr(),
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
                  title: Text('honors.evidence.delete_title'.tr()),
                  content: Text(
                    'honors.evidence.delete_content'.tr(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('honors.evidence.delete_cancel'.tr()),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                      child: Text('honors.evidence.delete_confirm'.tr()),
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
                color: AppColors.error.withAlpha(20),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPdf01,
                      color: AppColors.error,
                      size: 28,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PDF',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 400,
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
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedImageDelete01,
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
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
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
        color: AppColors.error.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: AppColors.error,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'honors.evidence.rejection_title'.tr(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason?.isNotEmpty == true
                      ? reason!
                      : 'honors.evidence.rejection_no_reason'.tr(),
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'honors.evidence.rejection_hint'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.error.withValues(alpha: 0.70),
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
  final VoidCallback onUploadCompletedFormat;
  final VoidCallback onAddEvidence;

  const _BottomCtaBar({
    required this.userHonor,
    required this.categoryColor,
    required this.onSubmit,
    required this.onUploadCompletedFormat,
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
    if (userHonor.isUnderReview) {
      return _CtaButton(
        label: 'honors.evidence.cta_sent'.tr(),
        icon: HugeIcons.strokeRoundedHourglass,
        color: AppColors.pendingColor,
        onPressed: null,
      );
    }

    if (userHonor.isCompleted) {
      return Builder(
        builder: (context) => _CtaButton(
          label: 'honors.evidence.cta_completed'.tr(),
          icon: HugeIcons.strokeRoundedAward01,
          color: AppColors.success,
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
    }

    if (!userHonor.hasCompletedFormat) {
      return _CtaButton(
        label: 'honors.evidence.cta_upload_format'.tr(),
        icon: HugeIcons.strokeRoundedPdf01,
        color: categoryColor,
        onPressed: onUploadCompletedFormat,
      );
    }

    if (!userHonor.hasGeneralEvidence) {
      return _CtaButton(
        label: 'honors.evidence.cta_upload_general'.tr(),
        icon: HugeIcons.strokeRoundedUpload01,
        color: categoryColor,
        onPressed: onAddEvidence,
      );
    }

    switch (userHonor.displayStatus) {
      case 'inscrito':
      case 'en_progreso':
        return _CtaButton(
          label: 'honors.evidence.cta_send'.tr(),
          icon: HugeIcons.strokeRoundedSent,
          color: categoryColor,
          isLoading: submitState.isLoading,
          onPressed: submitState.isLoading ? null : onSubmit,
        );

      case 'enviado':
        return _CtaButton(
          label: 'honors.evidence.cta_sent'.tr(),
          icon: HugeIcons.strokeRoundedHourglass,
          color: AppColors.pendingColor,
          onPressed: null,
        );

      case 'validado':
        return Builder(
          builder: (context) => _CtaButton(
            label: 'honors.evidence.cta_completed'.tr(),
            icon: HugeIcons.strokeRoundedAward01,
            color: AppColors.success,
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
        return _CtaButton(
          label: 'honors.evidence.cta_send'.tr(),
          icon: HugeIcons.strokeRoundedSent,
          color: categoryColor,
          isLoading: submitState.isLoading,
          onPressed: submitState.isLoading ? null : onSubmit,
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── CTA Button ────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String label;
  final HugeIconData icon;
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
    final foregroundColor = _heroForegroundColor(context, color);
    final disabledForegroundColor = Colors.white.withValues(alpha: 0.70);

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isDisabled ? AppColors.pendingColor : color,
          foregroundColor:
              isDisabled ? disabledForegroundColor : foregroundColor,
          disabledBackgroundColor: AppColors.pendingColor,
          disabledForegroundColor: disabledForegroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: isLoading
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: foregroundColor,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(icon: icon, size: 18),
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
