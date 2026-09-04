import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/staged_file.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/upload_progress_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../validation/domain/entities/validation.dart';
import '../../../validation/presentation/providers/validation_providers.dart'
    show submitValidationProvider;
import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';
import '../theme/honor_category_palette.dart';
import '../widgets/honor_badge_image.dart';
import '../widgets/honor_signed_evidence_image.dart';

/// Evidence & progress screen for an enrolled honor in EXTERNAL mode.
///
/// Working screen: white [SacTopBar], patch on page background, category color
/// as accent only. Drop wells for format and evidence; format opens the file
/// picker directly. The bottom bar is reserved for submit when both artifacts
/// are ready.
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
        backgroundColor: context.sac.background,
        appBar: SacTopBar(
          title: 'honors.evidence.error_load'.tr(),
          onBack: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        body: Center(child: Text('honors.evidence.error_load'.tr())),
      );
    }

    if (userHonor == null) {
      return Scaffold(
        backgroundColor: context.sac.background,
        appBar: SacTopBar(
          title: 'honors.evidence.not_found'.tr(),
          onBack: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
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
          onUploadCompletedFormat: _pickCompletedFormat,
          onAddEvidence: _showEvidencePickerOptions,
          onDeleteEvidence: (imageUrl) =>
              _deleteEvidenceFile(userHonor, imageUrl),
          onViewEvidence: _openEvidenceFile,
          onOpenDocument: _openCompletedFormat,
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

  void _showEvidencePickerOptions() {
    showSacSheet(
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

  void _openCompletedFormat(String url) {
    SacPdfViewer.show(
      context,
      pdfSource: url,
      title: 'honors.evidence.completed_format_title'.tr(),
    );
  }

  void _openEvidenceFile(
    String url,
    List<String> imageUrls,
    int initialIndex,
  ) {
    final lower = url.toLowerCase();
    final isPdf = lower.endsWith('.pdf') || lower.contains('/pdf');
    if (isPdf) {
      SacPdfViewer.show(
        context,
        pdfSource: url,
        title: 'honors.evidence.general_section_title'.tr(),
      );
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
      appBar: SacTopBar(
        title: title,
        onBack: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
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
            SacButton.outline(
              text: 'honors.evidence.mode_guard_back'.tr(),
              onPressed: () => context.pop(),
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
  final void Function(String url) onOpenDocument;
  final Future<void> Function(String url) onOpenMaterial;

  const _EvidenceBody({
    required this.userHonor,
    this.honor,
    required this.onSubmit,
    required this.onUploadCompletedFormat,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
    required this.onOpenDocument,
    required this.onOpenMaterial,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final categoryColor = getCategoryColor(
      categoryId: honor?.categoryId ?? userHonor.honorCategoryId,
      categoryName: honor?.categoryName ?? userHonor.honorCategoryName,
    );
    final categoryPaintColor = getCategoryPaintColor(
      categoryId: honor?.categoryId ?? userHonor.honorCategoryId,
      categoryName: honor?.categoryName ?? userHonor.honorCategoryName,
    );
    final honorName = honor?.name ??
        userHonor.honorName ??
        'honors.evidence.honor_fallback'.tr();
    final hasMaterial =
        honor?.materialUrl != null && honor!.materialUrl!.isNotEmpty;
    final showSubmitBar = userHonor.canSubmit &&
        userHonor.hasCompletedFormat &&
        userHonor.hasGeneralEvidence;

    var cardIndex = 0;
    Duration nextDelay() {
      final delay = SacMotion.stagger * cardIndex;
      cardIndex += 1;
      return delay;
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'honors.detail.external_flow_cta'.tr(),
        subtitle: honorName,
        onBack: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _EvidenceStatusBadge(userHonor: userHonor),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _EvidenceIdentity(
                          honor: honor,
                          userHonor: userHonor,
                        ),
                        const SizedBox(height: 24),
                        _CompletedFormatCard(
                          userHonor: userHonor,
                          categoryColor: categoryPaintColor,
                          animationDelay: nextDelay(),
                          onUploadCompletedFormat: onUploadCompletedFormat,
                          onOpenDocument: onOpenDocument,
                        ),
                        const SizedBox(height: 12),
                        _EvidenceSectionCard(
                          userHonor: userHonor,
                          categoryColor: categoryPaintColor,
                          animationDelay: nextDelay(),
                          onAddEvidence: onAddEvidence,
                          onDeleteEvidence: onDeleteEvidence,
                          onViewEvidence: onViewEvidence,
                        ),
                        if (hasMaterial) ...[
                          const SizedBox(height: 12),
                          _MaterialCard(
                            materialUrl: honor!.materialUrl!,
                            categoryColor: categoryPaintColor,
                            animationDelay: nextDelay(),
                            onOpen: onOpenMaterial,
                          ),
                        ],
                        if (userHonor.displayStatus == 'rechazado') ...[
                          const SizedBox(height: 16),
                          _RejectionCard(
                            reason: userHonor.rejectionReason,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showSubmitBar)
            _EvidenceSubmitBar(
              categoryColor: categoryColor,
              categoryPaintColor: categoryPaintColor,
              onSubmit: onSubmit,
            ),
        ],
      ),
    );
  }
}

class _EvidenceStatusBadge extends StatelessWidget {
  final UserHonor userHonor;

  const _EvidenceStatusBadge({required this.userHonor});

  @override
  Widget build(BuildContext context) {
    if (userHonor.isCompleted) {
      return SacBadge.success(
        label: 'honors.evidence.status_validated'.tr(),
      );
    }
    if (userHonor.isUnderReview) {
      return SacBadge(
        label: 'honors.evidence.status_sent'.tr(),
        variant: SacBadgeVariant.accent,
      );
    }
    if (userHonor.displayStatus == 'rechazado') {
      return SacBadge.error(
        label: 'honors.evidence.status_rejected'.tr(),
      );
    }
    return SacBadge(
      label: 'honors.evidence.status_enrolled'.tr(),
      variant: SacBadgeVariant.neutral,
    );
  }
}

const _kEvidenceBadgeSize = 132.0;

class _EvidenceIdentity extends StatelessWidget {
  final Honor? honor;
  final UserHonor userHonor;

  const _EvidenceIdentity({
    required this.honor,
    required this.userHonor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return _EnterScale(
      child: HonorBadgeImage(
        imageUrl: honor?.imageUrl ?? userHonor.honorImageUrl,
        width: _kEvidenceBadgeSize,
        height: _kEvidenceBadgeSize,
        memCacheWidth: (_kEvidenceBadgeSize * 3).round(),
        memCacheHeight: (_kEvidenceBadgeSize * 3).round(),
        fallbackColor: c.textTertiary,
        fallbackBackgroundColor: c.surfaceVariant,
        fallbackIconSize: 36,
        fallbackBorderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _EnterScale extends StatefulWidget {
  final Widget child;

  const _EnterScale({required this.child});

  @override
  State<_EnterScale> createState() => _EnterScaleState();
}

class _EnterScaleState extends State<_EnterScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.routeEnter,
    );
    _scale = Tween<double>(begin: SacMotion.enterScale, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;

    if (reduceMotion) {
      _controller.stop();
      _controller.value = 1;
      return;
    }

    if (firstRead) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Center(child: widget.child),
    );
  }
}

Widget _iconWell({
  required BuildContext context,
  required HugeIconData icon,
  required Color iconColor,
}) {
  return Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: context.sac.surfaceVariant,
      borderRadius: BorderRadius.circular(12),
    ),
    child: HugeIcon(icon: icon, color: iconColor, size: 22),
  );
}

class _DropWell extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final Color categoryColor;
  final bool enabled;

  const _DropWell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.categoryColor,
    required this.enabled,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = enabled ? categoryColor : c.border;
    final iconColor = enabled ? categoryColor : c.textTertiary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _DashedRRectPainter(color: accent),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.surface,
                  border: Border.all(color: accent, width: 1.5),
                ),
                child: HugeIcon(icon: icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null) ...[
                const SizedBox(height: 14),
                Text(
                  actionLabel!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: categoryColor,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;

  const _DashedRRectPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.5;
    const dashLength = 6.0;
    const gapLength = 4.0;
    const radius = 12.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      const Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length);
        canvas.drawPath(
          metric.extractPath(distance, end.toDouble()),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ── Material Card ─────────────────────────────────────────────────────────────

class _MaterialCard extends StatelessWidget {
  final String materialUrl;
  final Color categoryColor;
  final Duration animationDelay;
  final Future<void> Function(String url) onOpen;

  const _MaterialCard({
    required this.materialUrl,
    required this.categoryColor,
    required this.onOpen,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      animate: true,
      animationDelay: animationDelay,
      onTap: () => onOpen(materialUrl),
      child: Row(
        children: [
          _iconWell(
            context: context,
            icon: HugeIcons.strokeRoundedPdf01,
            iconColor: categoryColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'honors.evidence.material_title'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'honors.evidence.material_subtitle'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedDownload01,
            color: categoryColor,
            size: 20,
          ),
        ],
      ),
    );
  }
}

// ── Completed Format Card ────────────────────────────────────────────────────

class _CompletedFormatCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final Duration animationDelay;
  final VoidCallback onUploadCompletedFormat;
  final void Function(String url) onOpenDocument;

  const _CompletedFormatCard({
    required this.userHonor,
    required this.categoryColor,
    required this.onUploadCompletedFormat,
    required this.onOpenDocument,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasDocument = userHonor.hasCompletedFormat;
    final canEdit = userHonor.canSubmit;
    final documentUrl = userHonor.document;

    if (!hasDocument) {
      return SacCard(
        animate: true,
        animationDelay: animationDelay,
        padding: const EdgeInsets.all(12),
        onTap: canEdit ? onUploadCompletedFormat : null,
        child: _DropWell(
          icon: HugeIcons.strokeRoundedUpload01,
          title: 'honors.evidence.completed_format_title'.tr(),
          subtitle: 'honors.evidence.completed_format_missing'.tr(),
          actionLabel: canEdit
              ? 'honors.evidence.upload_completed_format'.tr()
              : null,
          categoryColor: categoryColor,
          enabled: canEdit,
        ),
      );
    }

    return SacCard(
      animate: true,
      animationDelay: animationDelay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconWell(
                context: context,
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                iconColor: AppColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'honors.evidence.completed_format_title'.tr(),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'honors.evidence.completed_format_uploaded'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (documentUrl != null)
                IconButton(
                  tooltip: 'honors.evidence.open_completed_format'.tr(),
                  onPressed: () => onOpenDocument(documentUrl),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedView,
                    color: c.textTertiary,
                    size: 20,
                  ),
                ),
            ],
          ),
          if (canEdit) ...[
            const SizedBox(height: 8),
            SacButton.ghost(
              text: 'honors.evidence.replace_completed_format'.tr(),
              icon: HugeIcons.strokeRoundedUpload01,
              textColor: categoryColor,
              iconSize: 16,
              fontSize: 13,
              onPressed: onUploadCompletedFormat,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Evidence Section Card ─────────────────────────────────────────────────────

class _EvidenceSectionCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final Duration animationDelay;
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
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    // canEdit: user may add or delete evidence (in_progress or rejected)
    final canEdit = userHonor.canSubmit;
    final showAddCell = canEdit && userHonor.generalEvidenceCount < 10;
    final hasEvidence = userHonor.images.isNotEmpty;

    if (!hasEvidence) {
      return SacCard(
        animate: true,
        animationDelay: animationDelay,
        padding: const EdgeInsets.all(12),
        onTap: showAddCell ? onAddEvidence : null,
        child: _DropWell(
          icon: HugeIcons.strokeRoundedImage01,
          title: 'honors.evidence.general_empty_first'.tr(),
          subtitle: 'honors.evidence.general_empty_subtitle'.tr(),
          actionLabel:
              showAddCell ? 'honors.evidence.add_button'.tr() : null,
          categoryColor: categoryColor,
          enabled: showAddCell,
        ),
      );
    }

    return SacCard(
      animate: true,
      animationDelay: animationDelay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'honors.evidence.general_section_title'.tr(),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.sac.text,
                  ),
                ),
              ),
              Text(
                '${userHonor.generalEvidenceCount}/10',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: categoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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

class _AddEvidenceCell extends StatefulWidget {
  final Color categoryColor;
  final VoidCallback onTap;

  const _AddEvidenceCell({
    required this.categoryColor,
    required this.onTap,
  });

  @override
  State<_AddEvidenceCell> createState() => _AddEvidenceCellState();
}

class _AddEvidenceCellState extends State<_AddEvidenceCell> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);

    return Semantics(
      button: true,
      label: 'honors.evidence.add_cell_label'.tr(),
      child: GestureDetector(
        onTapDown: (_) {
          HapticFeedback.lightImpact();
          _setPressed(true);
        },
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
          duration: SacMotion.press,
          curve: SacMotion.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: context.sac.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: widget.categoryColor.withValues(alpha: 0.40),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  color: widget.categoryColor,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  'honors.evidence.add_cell_label'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.categoryColor,
                  ),
                ),
              ],
            ),
          ),
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
          ? () async {
              HapticFeedback.mediumImpact();
              final confirmed = await SacDialog.show(
                context,
                title: 'honors.evidence.delete_title'.tr(),
                content: 'honors.evidence.delete_content'.tr(),
                cancelLabel: 'honors.evidence.delete_cancel'.tr(),
                confirmLabel: 'honors.evidence.delete_confirm'.tr(),
                confirmIsDestructive: true,
              );
              if (confirmed == true) onDelete();
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
              HonorSignedEvidenceImage(
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

class _EvidenceSubmitBar extends ConsumerWidget {
  final Color categoryColor;
  final Color categoryPaintColor;
  final VoidCallback onSubmit;

  const _EvidenceSubmitBar({
    required this.categoryColor,
    required this.categoryPaintColor,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final submitState = ref.watch(submitValidationProvider);
    final nearWhiteFill = isNearWhiteCategoryColor(categoryColor);

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SacButton.primary(
        text: 'honors.evidence.cta_send'.tr(),
        icon: HugeIcons.strokeRoundedSent,
        isLoading: submitState.isLoading,
        backgroundColor: categoryColor,
        textColor: onCategoryPaintColor(categoryColor, onNearWhite: c.text),
        borderColor: nearWhiteFill ? categoryPaintColor : null,
        onPressed: submitState.isLoading ? null : onSubmit,
      ),
    );
  }
}
