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

import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/staged_file.dart';
import 'package:sacdia_app/core/widgets/evidence_staging/upload_progress_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../validation/domain/entities/validation.dart';
import '../../../validation/presentation/providers/validation_providers.dart'
    show submitValidationProvider;
import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../providers/honors_providers.dart';
import '../theme/honor_category_palette.dart';
import '../utils/evidence_url.dart';
import '../utils/honor_submission_readiness.dart';
import '../widgets/honor_abandon_menu_button.dart';
import '../widgets/honor_band_scaffold.dart';
import '../widgets/honor_external_work_tab.dart';
import '../widgets/honor_progress_band.dart';
import '../widgets/honor_submit_bar.dart';
import '../widgets/honor_work_info_tab.dart';

/// Evidence & progress screen for an enrolled honor in EXTERNAL mode.
///
/// A colored band (patch, readiness ring, path) over two tabs: "Formato y
/// evidencias" (completed format, general evidence, material) and
/// "Información" (completion date, instructor, levels). The sticky bar always
/// tells what is missing and sends the honor to review once
/// [computeExternalSubmissionReadiness] says it can go.
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

    // Show loading only the first time: a refresh (after saving the instructor
    // or the date) keeps the screen, and the cards, where they are.
    if (userHonorsAsync.isLoading && !userHonorsAsync.hasValue) {
      return const Scaffold(body: Center(child: SacLoading()));
    }

    // Surface any hard error from userHonorsProvider
    if (userHonorsAsync.hasError) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: context.sac.background,
        appBar: SacTopBar(
            title: 'honors.evidence.error_load'.tr(),
            onBack: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            frosted: true),
        body: SacFrostedVeil(
          child: Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
              child: Center(child: Text('honors.evidence.error_load'.tr())),
            ),
          ),
        ),
      );
    }

    if (userHonor == null) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: context.sac.background,
        appBar: SacTopBar(
            title: 'honors.evidence.not_found'.tr(),
            onBack: () {
              HapticFeedback.lightImpact();
              context.pop();
            },
            frosted: true),
        body: SacFrostedVeil(
          child: Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
              child: Center(child: Text('honors.evidence.not_found'.tr())),
            ),
          ),
        ),
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
    if (!computeExternalSubmissionReadiness(userHonor: userHonor).canSubmit) {
      return;
    }
    HapticFeedback.mediumImpact();
    final notifier = ref.read(submitValidationProvider.notifier);
    final success = await notifier.submit(
      entityType: ValidationEntityType.honor,
      entityId: userHonor.id, // user_honor_id, NOT honor_id
    );
    if (!mounted) return;

    if (success) {
      // Refresh user honors to reflect new status.
      // userHonorStatsLocalProvider recomputes automatically when
      // userHonorsProvider is invalidated — no explicit invalidation needed.
      ref.invalidate(userHonorsProvider);
      ref.invalidate(userHonorForHonorProvider(widget.honorId));

      SacSnackBar.show(context, 'honors.evidence.sent_review'.tr(),
          isSuccess: true);
    } else {
      final state = ref.read(submitValidationProvider);
      SacSnackBar.show(
        context,
        userErrorMessage(state.failure ?? state.errorMessage),
        isError: true,
      );
    }
  }

  void _showEvidencePickerOptions() {
    showSacSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusMD)),
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
                borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
              ),
            ),
            const SizedBox(height: 16),
            SacPressable(
              listenOnly: true,
              child: ListTile(
                enableFeedback: false,
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
            ),
            SacPressable(
              listenOnly: true,
              child: ListTile(
                enableFeedback: false,
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
    final pickedFile = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

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
          SacSnackBar.show(
              context,
              'honors.evidence.file_size_error'
                  .tr(namedArgs: {'name': pickedFile.name}),
              isError: true);
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
            errorMessage: userErrorMessage(error),
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
        SacSnackBar.show(context, 'honors.evidence.no_session'.tr(),
            isError: true);
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
        SacSnackBar.show(
          context,
          success
              ? 'honors.evidence.delete_success'.tr()
              : 'honors.evidence.delete_error'.tr(),
          isError: !success,
        );
      }
    } catch (e) {
      if (mounted) {
        SacSnackBar.show(context, 'honors.evidence.delete_error'.tr(),
            isError: true);
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
    if (!isFetchableEvidenceUrl(url)) {
      // An unsigned storage key: there is no file the app can open.
      SacSnackBar.show(
        context,
        'honors.evidence.file_unavailable'.tr(),
        isError: true,
      );
      return;
    }
    if (isPdfEvidenceUrl(url)) {
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
      extendBodyBehindAppBar: true,
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
          title: title,
          onBack: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
          frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedRoute01,
                    size: 48,
                    color: SacAccent.of(context).color,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.sac.text,
                      fontSize: SacFontSize.headlineSmall,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.sac.textSecondary,
                      fontSize: SacFontSize.titleSmall,
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
          ),
        ),
      ),
    );
  }
}

// ── Evidence Body ─────────────────────────────────────────────────────────────

class _EvidenceBody extends ConsumerWidget {
  final UserHonor userHonor;
  final Honor? honor;
  final VoidCallback onSubmit;
  final VoidCallback onUploadCompletedFormat;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url, List<String> imageUrls, int initialIndex)
      onViewEvidence;
  final void Function(String url) onOpenDocument;

  const _EvidenceBody({
    required this.userHonor,
    this.honor,
    required this.onSubmit,
    required this.onUploadCompletedFormat,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
    required this.onOpenDocument,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryId = honor?.categoryId ?? userHonor.honorCategoryId;
    final categoryName = honor?.categoryName ??
        userHonor.honorCategoryName ??
        (categoryId != null
            ? ref.watch(categoryByIdProvider(categoryId))?.name
            : null);
    final paintColor = getCategoryPaintColor(
      categoryId: categoryId,
      categoryName: categoryName,
    );
    final bandColor = bandColorFor(
      categoryId: categoryId,
      categoryName: categoryName,
    );
    final onTint = honorOnTint(context, bandColor);
    final isSubmitting =
        ref.watch(submitValidationProvider.select((s) => s.isLoading));
    final honorName = (honor?.name.isNotEmpty ?? false)
        ? honor!.name
        : (userHonor.honorName ?? 'honors.evidence.honor_fallback'.tr());
    final material = honor?.materialUrl?.trim();
    final readiness = computeExternalSubmissionReadiness(userHonor: userHonor);
    final percent = (readiness.fraction * 100).round();
    final rejected = userHonor.validationStatus.toUpperCase() == 'REJECTED';

    return HonorBandScaffold(
      bandColor: bandColor,
      paintColor: paintColor,
      honorName: honorName,
      categoryName: categoryName,
      imageUrl: honor?.imageUrl ?? userHonor.honorImageUrl,
      progress: readiness.fraction,
      badge: rejected
          ? SacBadge.error(label: 'honors.detail.status_rejected'.tr())
          : userHonor.isUnderReview
              ? SacBadge.info(label: 'honors.detail.status_sent'.tr())
              : null,
      metaLabel: 'honors.requirements.band_meta'.tr(
        namedArgs: {
          'percent': '$percent',
          'mode': 'honors.detail.mode_external'.tr(),
        },
      ),
      step: honorWorkStepFor(userHonor),
      actions: [
        HonorAbandonMenuButton(
          userHonor: userHonor,
          honorName: honorName,
          iconColor: Colors.white,
        ),
      ],
      tabLabels: [
        'honors.detail.external_flow_cta'.tr(),
        'honors.requirements.tab_info'.tr(),
      ],
      tabBuilder: (context, tab) => tab == 0
          ? HonorExternalWorkTab(
              userHonor: userHonor,
              honorName: honorName,
              materialUrl:
                  (material != null && material.isNotEmpty) ? material : null,
              paintColor: paintColor,
              accent: onTint,
              onUploadCompletedFormat: onUploadCompletedFormat,
              onAddEvidence: onAddEvidence,
              onDeleteEvidence: onDeleteEvidence,
              onViewEvidence: onViewEvidence,
              onOpenDocument: onOpenDocument,
            )
          : HonorWorkInfoTab(
              userHonor: userHonor,
              honorId: userHonor.honorId,
              honor: honor,
              paintColor: paintColor,
              chipForeground: onTint,
            ),
      bottomBar: (userHonor.canSubmit || userHonor.isUnderReview)
          ? HonorSubmitBar(
              summary: HonorSubmitBar.summaryForExternal(readiness),
              canSubmit: readiness.canSubmit,
              bandColor: bandColor,
              isUnderReview: userHonor.isUnderReview,
              isSubmitting: isSubmitting,
              onSubmit: onSubmit,
            )
          : null,
    );
  }
}
