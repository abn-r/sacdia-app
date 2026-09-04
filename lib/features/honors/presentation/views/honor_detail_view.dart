import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/honor.dart';
import '../../domain/entities/requirement_evidence.dart';
import '../../domain/entities/user_honor_requirement_progress.dart';
import '../theme/honor_category_palette.dart';
import '../providers/honors_providers.dart';
import '../widgets/honor_badge_image.dart';
import '../widgets/honor_signed_evidence_image.dart';
import '../widgets/honor_work_mode_selector.dart';
import '../../domain/entities/user_honor.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

// Note: background, surface, text, and border colors are resolved at runtime
// via context.sac.* to support light and dark themes. See SacColors extension.
const _kScreenPad = 20.0;
const _kSectionGap = 24.0;
const _kHeroHeight = 300.0;
const _kCompletedBadgeSize = 148.0;

// ── Label helpers ─────────────────────────────────────────────────────────────

bool _isLightColor(Color color) => isNearWhiteCategoryColor(color);

Color _heroForegroundColor(BuildContext context, Color categoryColor) {
  return _isLightColor(categoryColor) ? context.sac.text : Colors.white;
}

Color _heroSecondaryForegroundColor(BuildContext context, Color categoryColor) {
  return _isLightColor(categoryColor)
      ? context.sac.textSecondary
      : Colors.white.withValues(alpha: 0.85);
}

Color _heroOverlayColor(BuildContext context, Color categoryColor) {
  return _isLightColor(categoryColor)
      ? context.sac.surfaceVariant.withValues(alpha: 0.85)
      : Colors.white.withValues(alpha: 0.20);
}

String _approvalLabel(int level) {
  switch (level) {
    case 1:
      return 'honors.detail.approval_general'.tr();
    case 2:
      return 'honors.detail.approval_advanced'.tr();
    case 3:
      return 'honors.detail.approval_master'.tr();
    default:
      return 'honors.detail.approval_level'.tr(namedArgs: {'level': '$level'});
  }
}

String _skillLevelLabel(int? level) {
  switch (level) {
    case 1:
      return 'honors.detail.skill_basic'.tr();
    case 2:
      return 'honors.detail.skill_intermediate'.tr();
    case 3:
      return 'honors.detail.skill_advanced'.tr();
    default:
      return level != null
          ? 'honors.detail.skill_level_n'.tr(namedArgs: {'level': '$level'})
          : '';
  }
}

String _completionModeLabel(HonorCompletionMode mode) {
  switch (mode) {
    case HonorCompletionMode.inApp:
      return 'honors.detail.mode_in_app'.tr();
    case HonorCompletionMode.external:
      return 'honors.detail.mode_external'.tr();
    case HonorCompletionMode.undecided:
      return 'honors.detail.mode_undecided'.tr();
  }
}

String _completionModeHistoryLabel(UserHonor userHonor) {
  if (userHonor.completionMode != HonorCompletionMode.undecided) {
    return _completionModeLabel(userHonor.completionMode);
  }

  if (!userHonor.isCompleted) {
    return _completionModeLabel(userHonor.completionMode);
  }

  if (_isExternalLegacyCompletedHonor(userHonor)) {
    return 'honors.detail.mode_external_legacy'.tr();
  }

  return 'honors.detail.mode_not_registered'.tr();
}

Future<void> _promptCompletionModeChange({
  required BuildContext context,
  required HonorCompletionMode currentMode,
  required Color categoryColor,
  required bool isLoading,
  required ValueChanged<HonorCompletionMode> onSelect,
}) async {
  final selectedMode = await showSacSheet<HonorCompletionMode>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final c = sheetContext.sac;
      return Padding(
        padding: const EdgeInsets.all(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'honors.detail.change_work_mode_cta'.tr(),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                HonorWorkModeSelector(
                  categoryColor: categoryColor,
                  isLoading: isLoading,
                  showIntro: false,
                  selectedMode: currentMode,
                  onSelected: (mode) => Navigator.of(sheetContext).pop(mode),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (!context.mounted || selectedMode == null || selectedMode == currentMode) {
    return;
  }

  onSelect(selectedMode);
}

bool _isExternalLegacyCompletedHonor(UserHonor userHonor) {
  if (!userHonor.isCompleted ||
      userHonor.completionMode != HonorCompletionMode.undecided) {
    return false;
  }

  return userHonor.hasCompletedFormat ||
      userHonor.images.isNotEmpty ||
      _trimmedOrNull(userHonor.certificate) != null;
}

String? _validatorRoleLabel(UserHonor userHonor) {
  final roleName = _trimmedOrNull(userHonor.validatedByRoleName);
  final roleLabel = _trimmedOrNull(userHonor.validatedByRoleLabel);

  if (roleLabel == null ||
      roleLabel.toLowerCase().startsWith('role:') ||
      roleLabel == roleName) {
    return _humanizeRoleName(roleName);
  }

  return roleLabel;
}

String? _humanizeRoleName(String? roleName) {
  final normalized = _trimmedOrNull(roleName);
  if (normalized == null) return null;

  return normalized
      .replaceAll(RegExp('[-_]'), ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _completionModeConfirmationMessageKey(HonorCompletionMode mode) {
  switch (mode) {
    case HonorCompletionMode.inApp:
      return 'honors.work_mode.confirm_in_app_message';
    case HonorCompletionMode.external:
      return 'honors.work_mode.confirm_external_message';
    case HonorCompletionMode.undecided:
      return 'honors.work_mode.confirm_message';
  }
}

String? _trimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _formatHistoryDate(BuildContext context, DateTime? date) {
  if (date == null) return 'honors.detail.history_not_available'.tr();

  final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'es';
  return DateFormat.yMMMd(locale).add_Hm().format(date.toLocal());
}

String _fileNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  final pathSegments =
      uri?.pathSegments.where((part) => part.trim().isNotEmpty).toList();
  final segment =
      pathSegments == null || pathSegments.isEmpty ? null : pathSegments.last;
  if (segment != null && segment.isNotEmpty) {
    return Uri.decodeComponent(segment);
  }

  final fallback = url.split('/').where((part) => part.trim().isNotEmpty);
  return fallback.isEmpty ? url : Uri.decodeComponent(fallback.last);
}

String _evidenceTypeLabel(EvidenceType type) {
  switch (type) {
    case EvidenceType.image:
      return 'honors.detail.evidence_type_image'.tr();
    case EvidenceType.file:
      return 'honors.detail.evidence_type_file'.tr();
    case EvidenceType.link:
      return 'honors.detail.evidence_type_link'.tr();
  }
}

HugeIconData _evidenceTypeIcon(EvidenceType type) {
  switch (type) {
    case EvidenceType.image:
      return HugeIcons.strokeRoundedImage01;
    case EvidenceType.file:
      return HugeIcons.strokeRoundedFile01;
    case EvidenceType.link:
      return HugeIcons.strokeRoundedLink01;
  }
}

bool _isPdfEvidenceUrl(String url) {
  final lowerPath = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  final lowerUrl = url.toLowerCase();
  return lowerPath.endsWith('.pdf') || lowerUrl.contains('/pdf');
}

bool _isImageEvidenceUrl(String url) {
  final lowerPath = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
  return lowerPath.endsWith('.jpg') ||
      lowerPath.endsWith('.jpeg') ||
      lowerPath.endsWith('.png') ||
      lowerPath.endsWith('.webp') ||
      lowerPath.endsWith('.gif') ||
      lowerPath.endsWith('.heic') ||
      lowerPath.endsWith('.heif');
}

Future<void> _openExternalHistoryUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !['http', 'https'].contains(uri.scheme)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('honors.detail.open_file_error'.tr()),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('honors.detail.open_file_error'.tr()),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _openHistoryAttachment(
  BuildContext context, {
  required String url,
  String? title,
  EvidenceType? evidenceType,
  List<String>? imageUrls,
  int initialIndex = 0,
}) async {
  if (_isPdfEvidenceUrl(url)) {
    SacPdfViewer.show(context, pdfSource: url, title: title);
    return;
  }

  final shouldOpenAsImage = evidenceType == EvidenceType.image ||
      imageUrls != null ||
      _isImageEvidenceUrl(url);
  if (shouldOpenAsImage) {
    SacImageViewer.show(
      context,
      imageUrl: url,
      title: title,
      imageUrls: imageUrls,
      initialIndex: initialIndex,
    );
    return;
  }

  await _openExternalHistoryUrl(context, url);
}

// ── Main View ─────────────────────────────────────────────────────────────────

class HonorDetailView extends ConsumerWidget {
  final int honorId;
  final Honor? initialHonor;

  const HonorDetailView({
    super.key,
    required this.honorId,
    this.initialHonor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialHonor != null) {
      return _HonorDetailContent(honor: initialHonor!, honorId: honorId);
    }

    final honorAsync = ref.watch(honorByIdProvider(honorId));
    return honorAsync.when(
      data: (honor) {
        if (honor == null) {
          return _ErrorScaffold(
              onRetry: () => ref.invalidate(allHonorsProvider));
        }
        return _HonorDetailContent(honor: honor, honorId: honorId);
      },
      loading: () => const _LoadingScaffold(),
      error: (_, __) =>
          _ErrorScaffold(onRetry: () => ref.invalidate(allHonorsProvider)),
    );
  }
}

// ── Loading Scaffold ───────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      body: Column(
        children: [
          Container(
            height: _kHeroHeight,
            color: AppColors.lightText.withValues(alpha: 0.85),
            child: const SafeArea(
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          Expanded(child: Container(color: context.sac.background)),
        ],
      ),
    );
  }
}

// ── Error Scaffold ─────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorScaffold({required this.onRetry});

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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
                icon: HugeIcons.strokeRoundedAlert02,
                size: 48,
                color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'honors.detail.error_load'.tr(),
              style: TextStyle(fontSize: 15, color: context.sac.textSecondary),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'honors.catalog.retry'.tr(),
                style: const TextStyle(color: AppColors.info, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Content ─────────────────────────────────────────────────────────────

class _HonorDetailContent extends ConsumerWidget {
  final Honor honor;
  final int honorId;

  const _HonorDetailContent({required this.honor, required this.honorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedUserHonor = ref.watch(userHonorForHonorProvider(honorId));
    final userHonorsLoading =
        ref.watch(userHonorsProvider.select((s) => s.isLoading));
    final enrollAsync = ref.watch(honorEnrollmentNotifierProvider);
    final modeActionState =
        ref.watch(honorCompletionModeActionsNotifierProvider);
    final modeActionUserHonor = modeActionState.valueOrNull;
    final userHonor = modeActionUserHonor?.honorId == honorId
        ? modeActionUserHonor
        : cachedUserHonor;

    final categoryName =
        ref.watch(categoryByIdProvider(honor.categoryId))?.name;

    final categoryColor = getCategoryColor(
      categoryId: honor.categoryId,
      categoryName: honor.categoryName ?? categoryName,
    );
    final categoryPaintColor = getCategoryPaintColor(
      categoryId: honor.categoryId,
      categoryName: honor.categoryName ?? categoryName,
    );
    final heroForegroundColor = _heroForegroundColor(context, categoryColor);
    final isEnrolled = userHonor != null;

    // After enrollment, refresh providers so UI switches to enrolled state
    if (!userHonorsLoading &&
        enrollAsync.hasValue &&
        enrollAsync.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.invalidate(userHonorsProvider);
          ref.invalidate(userHonorForHonorProvider(honorId));
          ref.invalidate(honorEnrollmentNotifierProvider);
        }
      });
    }

    if (userHonor != null && userHonor.isCompleted) {
      return _CompletedHonorDetail(
        honor: honor,
        honorId: honorId,
        userHonor: userHonor,
        categoryName: honor.categoryName ?? categoryName,
        categoryPaintColor: categoryPaintColor,
      );
    }

    if (userHonor != null &&
        userHonor.completionMode == HonorCompletionMode.undecided) {
      return _UndecidedWorkModeDetail(
        honor: honor,
        userHonor: userHonor,
        categoryName: honor.categoryName ?? categoryName,
        categoryColor: categoryColor,
        categoryPaintColor: categoryPaintColor,
        isLoading: modeActionState.isLoading,
        onSelectCompletionMode: (mode) =>
            _selectCompletionMode(context, ref, mode),
      );
    }

    if (userHonor != null &&
        userHonor.completionMode == HonorCompletionMode.external) {
      return _ExternalWorkModeDetail(
        honor: honor,
        userHonor: userHonor,
        categoryName: honor.categoryName ?? categoryName,
        categoryColor: categoryColor,
        categoryPaintColor: categoryPaintColor,
        isLoading: modeActionState.isLoading,
        onSelectCompletionMode: (mode) =>
            _selectCompletionMode(context, ref, mode),
      );
    }

    return Scaffold(
      backgroundColor: context.sac.background,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────
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
                      color: _heroOverlayColor(context, categoryColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowLeft01,
                      color: heroForegroundColor,
                      size: 22,
                    ),
                  ),
                ),
                title: Text(
                  categoryName ?? '',
                  style: TextStyle(
                    color: heroForegroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: isEnrolled
                    ? [
                        _StatusBadgePill(
                          status: userHonor.displayStatus,
                          defaultBackgroundColor:
                              _heroOverlayColor(context, categoryColor),
                          defaultForegroundColor: heroForegroundColor,
                        ),
                        const SizedBox(width: 12),
                      ]
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroSection(
                    honor: honor,
                    categoryColor: categoryColor,
                    foregroundColor: heroForegroundColor,
                    userHonor: userHonor,
                    honorId: honorId,
                    isEnrolled: isEnrolled,
                  ),
                ),
              ),

              // ── Body cards ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _kScreenPad),
                  child: _StaggeredCards(
                    honor: honor,
                    honorId: honorId,
                    categoryColor: categoryPaintColor,
                    userHonor: userHonor,
                    isEnrolled: isEnrolled,
                    userHonorsLoading: userHonorsLoading,
                    enrollAsync: enrollAsync,
                    modeActionState: modeActionState,
                    onSelectCompletionMode: (mode) =>
                        _selectCompletionMode(context, ref, mode),
                  ),
                ),
              ),
            ],
          ),

          // ── Floating CTA ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCtaBar(
              honor: honor,
              honorId: honorId,
              userHonor: userHonor,
              isEnrolled: isEnrolled,
              categoryColor: categoryPaintColor,
              userHonorsLoading: userHonorsLoading,
              enrollAsync: enrollAsync,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCompletionMode(
    BuildContext context,
    WidgetRef ref,
    HonorCompletionMode mode,
  ) async {
    final confirmed = await _confirmCompletionModeSelection(context, mode);
    if (!confirmed || !context.mounted) return;

    final user = ref.read(authNotifierProvider).valueOrNull ??
        await ref.read(authNotifierProvider.future);

    if (!context.mounted) return;

    final userId = user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('honors.detail.work_mode_no_session'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final success = await ref
        .read(honorCompletionModeActionsNotifierProvider.notifier)
        .updateCompletionMode(
          userId: userId,
          honorId: honorId,
          completionMode: mode,
        );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'honors.detail.work_mode_saved'.tr()
              : 'honors.detail.work_mode_error'.tr(),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<bool> _confirmCompletionModeSelection(
    BuildContext context,
    HonorCompletionMode mode,
  ) async {
    final result = await SacDialog.show(
      context,
      title: 'honors.work_mode.confirm_title'.tr(),
      content: _completionModeConfirmationMessageKey(mode).tr(),
      confirmLabel: 'common.confirm'.tr(),
    );

    return result ?? false;
  }
}

// ── Completed honor (validated) ───────────────────────────────────────────────

class _CompletedHonorDetail extends StatelessWidget {
  final Honor honor;
  final int honorId;
  final UserHonor userHonor;
  final String? categoryName;
  final Color categoryPaintColor;

  const _CompletedHonorDetail({
    required this.honor,
    required this.honorId,
    required this.userHonor,
    required this.categoryName,
    required this.categoryPaintColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final barTitle = _trimmedOrNull(categoryName) ?? honor.name;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 24;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: barTitle,
        onBack: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(hPad, 12, hPad, bottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CompletedHonorIdentity(honor: honor, userHonor: userHonor),
                  const SizedBox(height: 24),
                  _CompletedHonorHistorySection(
                    honorId: honorId,
                    userHonor: userHonor,
                    categoryColor: categoryPaintColor,
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

class _CompletedHonorIdentity extends StatelessWidget {
  final Honor honor;
  final UserHonor userHonor;

  const _CompletedHonorIdentity({
    required this.honor,
    required this.userHonor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final modeLabel = _completionModeHistoryLabel(userHonor);

    return _HonorHeroMotion(
      builder: (context, badgeScale, _) {
        return Column(
          children: [
            ScaleTransition(
              scale: badgeScale,
              child: HonorBadgeImage(
                imageUrl: honor.imageUrl,
                width: _kCompletedBadgeSize,
                height: _kCompletedBadgeSize,
                memCacheWidth: (_kCompletedBadgeSize * 3).round(),
                memCacheHeight: (_kCompletedBadgeSize * 3).round(),
                fallbackColor: c.textTertiary,
                fallbackBackgroundColor: c.surfaceVariant,
                fallbackIconSize: 40,
                fallbackBorderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              honor.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SacBadge.success(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  label: 'honors.detail.status_validated'.tr(),
                ),
                Text(
                  modeLabel,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── Undecided work mode ───────────────────────────────────────────────────────

class _UndecidedWorkModeDetail extends StatefulWidget {
  final Honor honor;
  final UserHonor userHonor;
  final String? categoryName;
  final Color categoryColor;
  final Color categoryPaintColor;
  final bool isLoading;
  final ValueChanged<HonorCompletionMode> onSelectCompletionMode;

  const _UndecidedWorkModeDetail({
    required this.honor,
    required this.userHonor,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryPaintColor,
    required this.isLoading,
    required this.onSelectCompletionMode,
  });

  @override
  State<_UndecidedWorkModeDetail> createState() =>
      _UndecidedWorkModeDetailState();
}

class _UndecidedWorkModeDetailState extends State<_UndecidedWorkModeDetail> {
  HonorCompletionMode? _selectedMode;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final barTitle = _trimmedOrNull(widget.categoryName) ?? widget.honor.name;
    final canChoose = widget.userHonor.canSubmit;
    final hasSelection = _selectedMode != null;

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: barTitle,
        subtitle: 'honors.detail.mode_undecided'.tr(),
        onBack: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
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
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkModeHonorIdentity(
                          honor: widget.honor,
                          userHonor: widget.userHonor,
                        ),
                        const SizedBox(height: 28),
                        if (!canChoose)
                          _LockedWorkModeCard(
                            userHonor: widget.userHonor,
                            categoryColor: widget.categoryPaintColor,
                          )
                        else ...[
                          Text(
                            'honors.work_mode.title'.tr(),
                            style: TextStyle(
                              color: c.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'honors.work_mode.subtitle'.tr(),
                            style: TextStyle(
                              color: c.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          HonorWorkModeSelector(
                            categoryColor: widget.categoryPaintColor,
                            isLoading: widget.isLoading,
                            showIntro: false,
                            selectedMode: _selectedMode,
                            onSelected: (mode) {
                              setState(() => _selectedMode = mode);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canChoose)
            _WorkModeContinueBar(
              hasSelection: hasSelection,
              isLoading: widget.isLoading,
              categoryColor: widget.categoryColor,
              categoryPaintColor: widget.categoryPaintColor,
              onContinue: () {
                final mode = _selectedMode;
                if (mode == null) return;
                widget.onSelectCompletionMode(mode);
              },
            ),
        ],
      ),
    );
  }
}

// ── External work mode ────────────────────────────────────────────────────────

class _ExternalWorkModeDetail extends StatelessWidget {
  final Honor honor;
  final UserHonor userHonor;
  final String? categoryName;
  final Color categoryColor;
  final Color categoryPaintColor;
  final bool isLoading;
  final ValueChanged<HonorCompletionMode> onSelectCompletionMode;

  const _ExternalWorkModeDetail({
    required this.honor,
    required this.userHonor,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryPaintColor,
    required this.isLoading,
    required this.onSelectCompletionMode,
  });

  Future<void> _changeWorkMode(BuildContext context) {
    return _promptCompletionModeChange(
      context: context,
      currentMode: HonorCompletionMode.external,
      categoryColor: categoryPaintColor,
      isLoading: isLoading,
      onSelect: onSelectCompletionMode,
    );
  }

  void _openEvidence(BuildContext context) {
    context.push(
      RouteNames.honorEvidencePath(
        honor.id.toString(),
        userHonor.id.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    final barTitle = _trimmedOrNull(categoryName) ?? honor.name;
    final canChangeCompletionMode = userHonor.canSubmit;
    final hasMaterial =
        honor.materialUrl != null && honor.materialUrl!.isNotEmpty;

    var cardIndex = 0;
    Duration nextDelay() {
      final delay = SacMotion.stagger * cardIndex;
      cardIndex += 1;
      return delay;
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: barTitle,
        onBack: () {
          HapticFeedback.lightImpact();
          context.pop();
        },
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
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _WorkModeHonorIdentity(
                          honor: honor,
                          userHonor: userHonor,
                          caption: _completionModeLabel(
                            HonorCompletionMode.external,
                          ),
                        ),
                        const SizedBox(height: 28),
                        _ExternalWorkflowInfoCard(
                          categoryColor: categoryPaintColor,
                          animationDelay: nextDelay(),
                        ),
                        if (canChangeCompletionMode) ...[
                          const SizedBox(height: 12),
                          _ChangeWorkModeButton(
                            categoryColor: categoryPaintColor,
                            isLoading: isLoading,
                            onPressed: () => _changeWorkMode(context),
                          ),
                        ],
                        if (hasMaterial) ...[
                          const SizedBox(height: 16),
                          _MaterialDownloadCard(
                            materialUrl: honor.materialUrl!,
                            categoryColor: categoryPaintColor,
                            animationDelay: nextDelay(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _EvidenceSection(
                          userHonor: userHonor,
                          categoryColor: categoryPaintColor,
                          animationDelay: nextDelay(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _ExternalWorkModeCtaBar(
            isUnderReview: userHonor.isUnderReview,
            categoryColor: categoryColor,
            categoryPaintColor: categoryPaintColor,
            onOpenEvidence: () => _openEvidence(context),
          ),
        ],
      ),
    );
  }
}

class _ExternalWorkModeCtaBar extends StatelessWidget {
  final bool isUnderReview;
  final Color categoryColor;
  final Color categoryPaintColor;
  final VoidCallback onOpenEvidence;

  const _ExternalWorkModeCtaBar({
    required this.isUnderReview,
    required this.categoryColor,
    required this.categoryPaintColor,
    required this.onOpenEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final padding = EdgeInsets.fromLTRB(
      16,
      12,
      16,
      12 + MediaQuery.paddingOf(context).bottom,
    );
    final chrome = BoxDecoration(
      color: c.surface,
      boxShadow: [
        BoxShadow(
          color: c.shadow,
          blurRadius: 12,
          offset: const Offset(0, -4),
        ),
      ],
    );

    if (isUnderReview) {
      return Container(
        padding: padding,
        decoration: chrome,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedHourglass,
              size: 16,
              color: AppColors.accent,
            ),
            const SizedBox(width: 8),
            Text(
              'honors.detail.under_review_cta'.tr(),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    final nearWhiteFill = isNearWhiteCategoryColor(categoryColor);

    return Container(
      padding: padding,
      decoration: chrome,
      child: SacButton.primary(
        text: 'honors.detail.external_flow_cta'.tr(),
        backgroundColor: categoryColor,
        textColor: onCategoryPaintColor(categoryColor, onNearWhite: c.text),
        borderColor: nearWhiteFill ? categoryPaintColor : null,
        onPressed: onOpenEvidence,
      ),
    );
  }
}

class _WorkModeHonorIdentity extends StatelessWidget {
  final Honor honor;
  final UserHonor userHonor;
  final String? caption;

  const _WorkModeHonorIdentity({
    required this.honor,
    required this.userHonor,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return _HonorHeroMotion(
      builder: (context, badgeScale, _) {
        return Column(
          children: [
            ScaleTransition(
              scale: badgeScale,
              child: HonorBadgeImage(
                imageUrl: honor.imageUrl,
                width: _kCompletedBadgeSize,
                height: _kCompletedBadgeSize,
                memCacheWidth: (_kCompletedBadgeSize * 3).round(),
                memCacheHeight: (_kCompletedBadgeSize * 3).round(),
                fallbackColor: c.textTertiary,
                fallbackBackgroundColor: c.surfaceVariant,
                fallbackIconSize: 40,
                fallbackBorderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              honor.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.text,
                    letterSpacing: -0.4,
                    height: 1.15,
                  ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SacBadge(
                  label: userHonor.isUnderReview
                      ? 'honors.detail.status_sent'.tr()
                      : 'honors.detail.status_enrolled'.tr(),
                  variant: userHonor.isUnderReview
                      ? SacBadgeVariant.accent
                      : SacBadgeVariant.neutral,
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _WorkModeContinueBar extends StatelessWidget {
  final bool hasSelection;
  final bool isLoading;
  final Color categoryColor;
  final Color categoryPaintColor;
  final VoidCallback onContinue;

  const _WorkModeContinueBar({
    required this.hasSelection,
    required this.isLoading,
    required this.categoryColor,
    required this.categoryPaintColor,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final canSubmit = hasSelection && !isLoading;
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
        text: hasSelection
            ? 'honors.work_mode.continue_cta'.tr()
            : 'honors.detail.select_mode_cta'.tr(),
        isLoading: isLoading,
        backgroundColor: canSubmit ? categoryColor : c.surfaceVariant,
        textColor: canSubmit
            ? onCategoryPaintColor(categoryColor, onNearWhite: c.text)
            : c.textTertiary,
        borderColor:
            canSubmit && nearWhiteFill ? categoryPaintColor : null,
        onPressed: canSubmit ? onContinue : null,
      ),
    );
  }
}

// ── Hero Section ───────────────────────────────────────────────────────────────

class _HonorHeroMotion extends StatefulWidget {
  const _HonorHeroMotion({required this.builder});

  final Widget Function(
    BuildContext context,
    Animation<double> badgeScale,
    Animation<double> progressValue,
  ) builder;

  @override
  State<_HonorHeroMotion> createState() => _HonorHeroMotionState();
}

class _HonorHeroMotionState extends State<_HonorHeroMotion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _badgeScale;
  late Animation<double> _progressValue;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.routeEnter,
    );

    _badgeScale = Tween<double>(
      begin: SacMotion.enterScale,
      end: 1,
    ).animate(
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut),
    );

    _progressValue = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstDependencyRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;

    if (reduceMotion) {
      _controller.stop();
      _controller.value = 1;
      return;
    }

    if (firstDependencyRead) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _badgeScale, _progressValue);
}

class _HeroSection extends ConsumerStatefulWidget {
  final Honor honor;
  final Color categoryColor;
  final Color foregroundColor;
  final UserHonor? userHonor;
  final int honorId;
  final bool isEnrolled;

  const _HeroSection({
    required this.honor,
    required this.categoryColor,
    required this.foregroundColor,
    required this.userHonor,
    required this.honorId,
    required this.isEnrolled,
  });

  @override
  ConsumerState<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends ConsumerState<_HeroSection> {
  @override
  Widget build(BuildContext context) {
    final showInAppProgress = widget.isEnrolled &&
        widget.userHonor?.completionMode == HonorCompletionMode.inApp;
    final progressStats = showInAppProgress
        ? ref.watch(honorProgressStatsProvider(widget.honorId))
        : null;
    final progressPercent = progressStats?.percentage ?? 0.0;
    final heroSecondaryForeground =
        _heroSecondaryForegroundColor(context, widget.categoryColor);
    final heroOverlay = _heroOverlayColor(context, widget.categoryColor);

    return _HonorHeroMotion(
      builder: (context, badgeScale, progressValue) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.categoryColor,
              widget.categoryColor.withValues(alpha: 0.72),
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
                ScaleTransition(
                  scale: badgeScale,
                  child: widget.isEnrolled
                      ? _ProgressBadge(
                          honor: widget.honor,
                          categoryColor: widget.categoryColor,
                          progressValue: progressValue,
                          progressPercent: progressPercent,
                        )
                      : _SimpleBadge(honor: widget.honor),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.honor.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.foregroundColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                if (showInAppProgress && progressStats != null) ...[
                  Text(
                    'honors.detail.progress_summary'.tr(namedArgs: {
                      'completed': '${progressStats.completed}',
                      'total': '${progressStats.total}',
                    }),
                    style: TextStyle(
                      color: heroSecondaryForeground,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedBuilder(
                    animation: progressValue,
                    builder: (context, _) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressValue.value * progressPercent,
                          minHeight: 4,
                          backgroundColor: heroOverlay,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            widget.foregroundColor,
                          ),
                        ),
                      );
                    },
                  ),
                ] else if (widget.isEnrolled && widget.userHonor != null) ...[
                  _FrostedPill(
                    label:
                        _completionModeLabel(widget.userHonor!.completionMode),
                    foregroundColor: widget.foregroundColor,
                    backgroundColor: heroOverlay,
                  ),
                ] else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      if (widget.honor.skillLevel != null)
                        _FrostedPill(
                          label: _skillLevelLabel(widget.honor.skillLevel),
                          foregroundColor: widget.foregroundColor,
                          backgroundColor: heroOverlay,
                        ),
                      _FrostedPill(
                        label: _approvalLabel(widget.honor.approval),
                        foregroundColor: widget.foregroundColor,
                        backgroundColor: heroOverlay,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleBadge extends StatelessWidget {
  final Honor honor;

  const _SimpleBadge({required this.honor});

  @override
  Widget build(BuildContext context) {
    return _BadgeImage(honor: honor, size: 110);
  }
}

class _ProgressBadge extends StatelessWidget {
  final Honor honor;
  final Color categoryColor;
  final Animation<double> progressValue;
  final double progressPercent;

  const _ProgressBadge({
    required this.honor,
    required this.categoryColor,
    required this.progressValue,
    required this.progressPercent,
  });

  @override
  Widget build(BuildContext context) {
    return _BadgeImage(honor: honor, size: 130);
  }
}

class _BadgeImage extends StatelessWidget {
  final Honor honor;
  final double size;

  const _BadgeImage({required this.honor, required this.size});

  @override
  Widget build(BuildContext context) {
    return HonorBadgeImage(
      imageUrl: honor.imageUrl,
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      memCacheWidth: (size * 3).round(),
      memCacheHeight: (size * 3).round(),
      fallbackColor: AppColors.lightText,
      fallbackBackgroundColor: Colors.white.withValues(alpha: 0.20),
      fallbackIconSize: 36,
      fallbackBorderRadius: BorderRadius.circular(18),
    );
  }
}

class _FrostedPill extends StatelessWidget {
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;

  const _FrostedPill({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusBadgePill extends StatelessWidget {
  final String status;
  final Color defaultBackgroundColor;
  final Color defaultForegroundColor;

  const _StatusBadgePill({
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
        return 'honors.detail.status_validated'.tr();
      case 'enviado':
        return 'honors.detail.status_sent'.tr();
      case 'en_progreso':
        return 'honors.detail.status_in_progress'.tr();
      case 'rechazado':
        return 'honors.detail.status_rejected'.tr();
      default:
        return 'honors.detail.status_enrolled'.tr();
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
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Staggered Cards Body ───────────────────────────────────────────────────────

class _StaggeredCards extends StatefulWidget {
  final Honor honor;
  final int honorId;
  final Color categoryColor;
  final UserHonor? userHonor;
  final bool isEnrolled;
  final bool userHonorsLoading;
  final AsyncValue<UserHonor?> enrollAsync;
  final AsyncValue<void> modeActionState;
  final ValueChanged<HonorCompletionMode> onSelectCompletionMode;

  const _StaggeredCards({
    required this.honor,
    required this.honorId,
    required this.categoryColor,
    required this.userHonor,
    required this.isEnrolled,
    required this.userHonorsLoading,
    required this.enrollAsync,
    required this.modeActionState,
    required this.onSelectCompletionMode,
  });

  @override
  State<_StaggeredCards> createState() => _StaggeredCardsState();
}

class _StaggeredCardsState extends State<_StaggeredCards>
    with SingleTickerProviderStateMixin {
  // Single controller drives all stagger animations via per-card Intervals.
  // Saves N-1 controllers vs the previous design (one per card).
  static const int _count = 4;
  static const Duration _totalDuration = Duration(milliseconds: 800);
  static const double _cardWindow = 350 / 800; // 0.4375
  static const double _cardOffset = 100 / 800; // 0.125 between starts
  static const double _baseStart = 150 / 800; // first card kickoff

  late final AnimationController _controller;
  late final List<Animation<double>> _fadeAnims;
  late final List<Animation<Offset>> _slideAnims;
  bool? _reduceMotion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _totalDuration);
    _fadeAnims = List.generate(_count, (i) {
      final start = _baseStart + i * _cardOffset;
      final end = (start + _cardWindow).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(start, end, curve: Curves.easeOut),
        ),
      );
    });
    _slideAnims = List.generate(_count, (i) {
      final start = _baseStart + i * _cardOffset;
      final end = (start + _cardWindow).clamp(0.0, 1.0);
      return Tween<Offset>(
        begin: const Offset(0, 0.08),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Interval(start, end, curve: Curves.easeOut),
      ));
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final reduceMotion = SacMotion.reduceMotionOf(context);
    if (_reduceMotion == reduceMotion) return;

    final firstDependencyRead = _reduceMotion == null;
    _reduceMotion = reduceMotion;

    if (reduceMotion) {
      _controller.stop();
      _controller.value = 1;
      return;
    }

    if (firstDependencyRead) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    final idx = index.clamp(0, _count - 1);
    return FadeTransition(
      opacity: _fadeAnims[idx],
      child: SlideTransition(position: _slideAnims[idx], child: child),
    );
  }

  Future<void> _changeWorkMode(HonorCompletionMode currentMode) {
    return _promptCompletionModeChange(
      context: context,
      currentMode: currentMode,
      categoryColor: widget.categoryColor,
      isLoading: widget.modeActionState.isLoading,
      onSelect: widget.onSelectCompletionMode,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEnrolled) {
      final userHonor = widget.userHonor!;
      final completionMode = userHonor.completionMode;
      final canChangeCompletionMode = userHonor.canSubmit;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _kSectionGap),

          // Quick stats row
          _animated(
            0,
            _QuickStatsRow(
              honorId: widget.honorId,
              userHonor: userHonor,
              categoryColor: widget.categoryColor,
            ),
          ),
          const SizedBox(height: _kSectionGap),

          // Requirements preview
          _animated(
            1,
            _RequirementsPreviewCard(
              honorId: widget.honorId,
              userHonorId: userHonor.id,
              honorName: widget.honor.name,
              categoryColor: widget.categoryColor,
            ),
          ),
          if (canChangeCompletionMode) ...[
            const SizedBox(height: 12),
            _animated(
              2,
              _ChangeWorkModeButton(
                categoryColor: widget.categoryColor,
                isLoading: widget.modeActionState.isLoading,
                onPressed: () => _changeWorkMode(completionMode),
              ),
            ),
          ],

          // Bottom padding for CTA
          const SizedBox(height: 100),
        ],
      );
    }

    // NOT ENROLLED state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _kSectionGap),
        _animated(
          0,
          _JourneyPreviewCard(
            honor: widget.honor,
            honorId: widget.honorId,
            categoryColor: widget.categoryColor,
          ),
        ),
        if (widget.honor.description != null &&
            widget.honor.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _animated(
            1,
            _DescriptionSection(description: widget.honor.description),
          ),
        ],
        const SizedBox(height: 16),
        _animated(
          2,
          _JourneyStepperPath(categoryColor: widget.categoryColor),
        ),
        const SizedBox(height: 120),
      ],
    );
  }
}

class _CompletedHonorHistorySection extends ConsumerWidget {
  final int honorId;
  final UserHonor userHonor;
  final Color categoryColor;

  const _CompletedHonorHistorySection({
    required this.honorId,
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLegacyExternal = _isExternalLegacyCompletedHonor(userHonor);
    final showExternalHistory =
        userHonor.hasCompletedFormat || userHonor.images.isNotEmpty;
    final showRequirementsHistory =
        userHonor.completionMode != HonorCompletionMode.external &&
            !isLegacyExternal;
    final progressAsync = showRequirementsHistory
        ? ref.watch(userHonorProgressProvider(honorId))
        : null;

    var cardIndex = 0;
    Duration nextDelay() {
      final delay = SacMotion.stagger * cardIndex;
      cardIndex += 1;
      return delay;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ValidationHistoryCard(
          userHonor: userHonor,
          animationDelay: nextDelay(),
        ),
        if (showExternalHistory) ...[
          const SizedBox(height: 16),
          _ExternalWorkHistoryCard(
            userHonor: userHonor,
            categoryColor: categoryColor,
            animationDelay: nextDelay(),
          ),
        ],
        if (showRequirementsHistory) ...[
          const SizedBox(height: 16),
          _RequirementsHistoryCard(
            progressAsync: progressAsync!,
            categoryColor: categoryColor,
            animationDelay: nextDelay(),
          ),
        ],
      ],
    );
  }
}

class _ValidationHistoryCard extends StatelessWidget {
  final UserHonor userHonor;
  final Duration animationDelay;

  const _ValidationHistoryCard({
    required this.userHonor,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final validator = _trimmedOrNull(userHonor.validatedByName) ??
        'honors.detail.history_not_available'.tr();
    final validatorRole = _validatorRoleLabel(userHonor);
    final rows = <Widget>[
      _HistoryInfoRow(
        icon: HugeIcons.strokeRoundedCalendar01,
        label: 'honors.detail.history_registered_label'.tr(),
        value: _formatHistoryDate(context, userHonor.date),
      ),
      _HistoryInfoRow(
        icon: HugeIcons.strokeRoundedClock01,
        label: 'honors.detail.history_submitted_label'.tr(),
        value: _formatHistoryDate(context, userHonor.submittedAt),
      ),
      _HistoryInfoRow(
        icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        label: 'honors.detail.history_validated_label'.tr(),
        value: _formatHistoryDate(context, userHonor.validatedAt),
        highlight: true,
      ),
      _HistoryInfoRow(
        icon: HugeIcons.strokeRoundedUser,
        label: 'honors.detail.history_validated_by_label'.tr(),
        value: validator,
        detail: validatorRole,
      ),
    ];

    return SacCard(
      animate: true,
      animationDelay: animationDelay,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'honors.detail.validation_history_title'.tr(),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
          ),
          const SizedBox(height: 4),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: c.border),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _HistoryInfoRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool highlight;

  const _HistoryInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = highlight ? AppColors.success : c.textTertiary;
    final well = highlight
        ? AppColors.success.withValues(alpha: 0.12)
        : c.surfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: well,
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: icon, size: 16, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.sac.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: context.sac.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (_trimmedOrNull(detail) != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(
                      color: context.sac.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalWorkHistoryCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final Duration animationDelay;

  const _ExternalWorkHistoryCard({
    required this.userHonor,
    required this.categoryColor,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final imageEvidenceUrls = userHonor.images
        .where((url) => !_isPdfEvidenceUrl(url))
        .toList(growable: false);

    return SacCard(
      animate: true,
      animationDelay: animationDelay,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HistorySectionHeader(
            icon: HugeIcons.strokeRoundedFiles01,
            title: 'honors.detail.external_history_title'.tr(),
            subtitle: 'honors.detail.external_history_subtitle'.tr(),
            categoryColor: categoryColor,
          ),
          const SizedBox(height: 14),
          if (userHonor.hasCompletedFormat)
            _HistoryFileRow(
              title: 'honors.detail.completed_format_file'.tr(),
              subtitle: _fileNameFromUrl(userHonor.document!),
              url: userHonor.document!,
              icon: HugeIcons.strokeRoundedPdf01,
              categoryColor: categoryColor,
            ),
          if (userHonor.hasCompletedFormat && userHonor.images.isNotEmpty)
            const SizedBox(height: 10),
          ...userHonor.images.asMap().entries.map((entry) {
            final title = 'honors.detail.general_evidence_item'.tr(
              namedArgs: {'index': '${entry.key + 1}'},
            );
            final url = entry.value;
            final bottom =
                entry.key == userHonor.images.length - 1 ? 0.0 : 10.0;

            if (_isPdfEvidenceUrl(url)) {
              return Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: _HistoryFileRow(
                  title: title,
                  subtitle: _fileNameFromUrl(url),
                  url: url,
                  icon: HugeIcons.strokeRoundedPdf01,
                  categoryColor: categoryColor,
                  evidenceType: EvidenceType.file,
                ),
              );
            }

            final initialIndex = imageEvidenceUrls.indexOf(url);
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: _HistoryImageRow(
                title: title,
                url: url,
                categoryColor: categoryColor,
                imageUrls: imageEvidenceUrls,
                initialIndex: initialIndex < 0 ? 0 : initialIndex,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RequirementsHistoryCard extends StatelessWidget {
  final AsyncValue<List<UserHonorRequirementProgress>> progressAsync;
  final Color categoryColor;
  final Duration animationDelay;

  const _RequirementsHistoryCard({
    required this.progressAsync,
    required this.categoryColor,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    return progressAsync.when(
      data: (progressList) {
        return SacCard(
          animate: true,
          animationDelay: animationDelay,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistorySectionHeader(
                icon: HugeIcons.strokeRoundedTaskDone01,
                title: 'honors.detail.requirements_history_title'.tr(),
                subtitle: 'honors.detail.requirements_history_subtitle'.tr(),
                categoryColor: categoryColor,
              ),
              const SizedBox(height: 14),
              if (progressList.isEmpty)
                Text(
                  'honors.detail.requirements_history_empty'.tr(),
                  style: TextStyle(
                    color: context.sac.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                )
              else
                ...progressList.asMap().entries.map(
                      (entry) => Padding(
                        padding: EdgeInsets.only(
                          bottom: entry.key == progressList.length - 1 ? 0 : 12,
                        ),
                        child: _RequirementHistoryItem(
                          requirement: entry.value,
                          categoryColor: categoryColor,
                        ),
                      ),
                    ),
            ],
          ),
        );
      },
      loading: () => SacCard(
        animate: true,
        animationDelay: animationDelay,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: categoryColor,
          ),
        ),
      ),
      error: (_, __) => SacCard(
        animate: true,
        animationDelay: animationDelay,
        padding: const EdgeInsets.all(16),
        child: Text(
          'honors.detail.requirements_history_error'.tr(),
          style: TextStyle(
            color: context.sac.textSecondary,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _HistorySectionHeader extends StatelessWidget {
  final HugeIconData icon;
  final String title;
  final String subtitle;
  final Color categoryColor;

  const _HistorySectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
          ),
          child: HugeIcon(icon: icon, size: 18, color: categoryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequirementHistoryItem extends StatelessWidget {
  final UserHonorRequirementProgress requirement;
  final Color categoryColor;

  const _RequirementHistoryItem({
    required this.requirement,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final response = _trimmedOrNull(requirement.textResponse);
    final notes = _trimmedOrNull(requirement.notes);
    final imageEvidenceUrls = requirement.evidences
        .where((evidence) =>
            evidence.evidenceType == EvidenceType.image ||
            (!_isPdfEvidenceUrl(evidence.url) &&
                _isImageEvidenceUrl(evidence.url)))
        .map((evidence) => evidence.url)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.sac.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: requirement.completed
                      ? AppColors.success.withValues(alpha: 0.14)
                      : categoryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${requirement.requirementNumber}',
                  style: TextStyle(
                    color: requirement.completed
                        ? AppColors.success
                        : categoryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  requirement.text,
                  style: TextStyle(
                    color: context.sac.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              HugeIcon(
                icon: requirement.completed
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedClock01,
                size: 18,
                color: requirement.completed
                    ? AppColors.success
                    : context.sac.textTertiary,
              ),
            ],
          ),
          if (response != null) ...[
            const SizedBox(height: 12),
            _HistoryTextBlock(
              label: 'honors.detail.requirement_response_label'.tr(),
              value: response,
            ),
          ],
          if (notes != null) ...[
            const SizedBox(height: 10),
            _HistoryTextBlock(
              label: 'honors.detail.requirement_notes_label'.tr(),
              value: notes,
            ),
          ],
          if (requirement.completedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'honors.detail.requirement_completed_at_label'.tr(
                namedArgs: {
                  'date': _formatHistoryDate(context, requirement.completedAt),
                },
              ),
              style: TextStyle(
                color: context.sac.textTertiary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (requirement.evidences.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'honors.detail.requirement_evidence_count'.tr(
                namedArgs: {'count': '${requirement.evidences.length}'},
              ),
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...requirement.evidences.map(
              (evidence) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RequirementEvidenceHistoryRow(
                  evidence: evidence,
                  categoryColor: categoryColor,
                  imageUrls: imageEvidenceUrls,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryTextBlock extends StatelessWidget {
  final String label;
  final String value;

  const _HistoryTextBlock({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.sac.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.sac.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: context.sac.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequirementEvidenceHistoryRow extends StatelessWidget {
  final RequirementEvidence evidence;
  final Color categoryColor;
  final List<String> imageUrls;

  const _RequirementEvidenceHistoryRow({
    required this.evidence,
    required this.categoryColor,
    required this.imageUrls,
  });

  @override
  Widget build(BuildContext context) {
    final title =
        _trimmedOrNull(evidence.filename) ?? _fileNameFromUrl(evidence.url);
    final subtitle = _evidenceTypeLabel(evidence.evidenceType);

    final initialIndex = imageUrls.indexOf(evidence.url);

    return _HistoryFileRow(
      title: title,
      subtitle: subtitle,
      url: evidence.url,
      icon: _evidenceTypeIcon(evidence.evidenceType),
      categoryColor: categoryColor,
      evidenceType: evidence.evidenceType,
      imageUrls: imageUrls.isEmpty ? null : imageUrls,
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
    );
  }
}

class _HistoryPressable extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HistoryPressable({
    required this.onTap,
    required this.child,
  });

  @override
  State<_HistoryPressable> createState() => _HistoryPressableState();
}

class _HistoryPressableState extends State<_HistoryPressable> {
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
          child: widget.child,
        ),
      ),
    );
  }
}

class _HistoryFileRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String url;
  final HugeIconData icon;
  final Color categoryColor;
  final EvidenceType? evidenceType;
  final List<String>? imageUrls;
  final int initialIndex;

  const _HistoryFileRow({
    required this.title,
    required this.subtitle,
    required this.url,
    required this.icon,
    required this.categoryColor,
    this.evidenceType,
    this.imageUrls,
    this.initialIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return _HistoryPressable(
      onTap: () => _openHistoryAttachment(
        context,
        url: url,
        title: title,
        evidenceType: evidenceType,
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.sac.border),
        ),
        child: Row(
          children: [
            HugeIcon(icon: icon, size: 20, color: categoryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.sac.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.sac.textTertiary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            HugeIcon(
              icon: HugeIcons.strokeRoundedLink01,
              size: 16,
              color: context.sac.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryImageRow extends StatelessWidget {
  final String title;
  final String url;
  final Color categoryColor;
  final List<String> imageUrls;
  final int initialIndex;

  const _HistoryImageRow({
    required this.title,
    required this.url,
    required this.categoryColor,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return _HistoryPressable(
      onTap: () => _openHistoryAttachment(
        context,
        url: url,
        title: title,
        evidenceType: EvidenceType.image,
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 58),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.sac.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: HonorSignedEvidenceImage(
                imageUrl: url,
                width: 42,
                height: 42,
                fit: BoxFit.cover,
                memCacheWidth: 126,
                memCacheHeight: 126,
                errorWidget: (_, __, ___) => Container(
                  width: 42,
                  height: 42,
                  color: context.sac.border,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedImageDelete01,
                    size: 18,
                    color: context.sac.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.sac.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedLink01,
              size: 16,
              color: categoryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedWorkModeCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;

  const _LockedWorkModeCard({
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final messageKey = userHonor.isUnderReview
        ? 'honors.detail.work_mode_locked_under_review'
        : userHonor.isCompleted
            ? 'honors.detail.work_mode_locked_completed'
            : 'honors.detail.work_mode_locked_default';

    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedLock,
                    size: 24,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'honors.detail.work_mode_locked_title'.tr(),
                    style: TextStyle(
                      color: context.sac.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              messageKey.tr(),
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangeWorkModeButton extends StatelessWidget {
  final Color categoryColor;
  final bool isLoading;
  final VoidCallback onPressed;

  const _ChangeWorkModeButton({
    required this.categoryColor,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacButton.outline(
      text: 'honors.detail.change_work_mode_cta'.tr(),
      icon: HugeIcons.strokeRoundedRefresh,
      isLoading: isLoading,
      backgroundColor: c.surface,
      textColor: categoryColor,
      borderColor: categoryColor.withValues(alpha: 0.35),
      onPressed: isLoading ? null : onPressed,
    );
  }
}

// ── Journey Preview Card (NOT ENROLLED) ───────────────────────────────────────

class _JourneyPreviewCard extends ConsumerWidget {
  final Honor honor;
  final int honorId;
  final Color categoryColor;

  const _JourneyPreviewCard({
    required this.honor,
    required this.honorId,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirementsAsync = ref.watch(honorRequirementsProvider(honorId));
    final requirementsCount = requirementsAsync.maybeWhen(
      data: (reqs) => reqs.length,
      orElse: () => null,
    );

    return _ShadowCard(
      child: Column(
        children: [
          _PreviewRow(
            icon: HugeIcons.strokeRoundedTaskEdit01,
            iconColor: categoryColor,
            label: requirementsCount != null
                ? 'honors.detail.requirements_count'
                    .tr(namedArgs: {'count': '$requirementsCount'})
                : 'honors.detail.requirements_loading'.tr(),
          ),
          _CardDivider(),
          _PreviewRow(
            icon: HugeIcons.strokeRoundedStar,
            iconColor: categoryColor,
            label: honor.skillLevel != null
                ? 'honors.detail.skill_level_with'.tr(
                    namedArgs: {'level': _skillLevelLabel(honor.skillLevel)})
                : 'honors.detail.skill_level_general'.tr(),
          ),
          if (honor.materialUrl != null && honor.materialUrl!.isNotEmpty) ...[
            _CardDivider(),
            _PreviewRow(
              icon: HugeIcons.strokeRoundedPdf01,
              iconColor: categoryColor,
              label: 'honors.detail.material_available'.tr(),
              trailing: HugeIcon(
                icon: HugeIcons.strokeRoundedDownload01,
                size: 16,
                color: categoryColor,
              ),
            ),
          ],
          const SizedBox(width: 300),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final HugeIconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;

  const _PreviewRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(icon: icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.sac.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.sac.border,
    );
  }
}

// ── Description Section ───────────────────────────────────────────────────────

class _DescriptionSection extends StatefulWidget {
  final String? description;

  const _DescriptionSection({required this.description});

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.description == null || widget.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'honors.detail.description_label'.tr(),
              style: TextStyle(
                color: context.sac.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Text(
                widget.description!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.sac.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              secondChild: Text(
                widget.description!,
                style: TextStyle(
                  color: context.sac.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded
                    ? 'honors.detail.see_less'.tr()
                    : 'honors.detail.see_more'.tr(),
                style: TextStyle(
                  color: AppColors.info,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Journey Stepper Path (NOT ENROLLED — ¿Cómo funciona?) ────────────────────

class _JourneyStepperPath extends StatelessWidget {
  final Color categoryColor;

  const _JourneyStepperPath({required this.categoryColor});

  @override
  Widget build(BuildContext context) {
    final steps = [
      (
        title: 'honors.detail.step1_title'.tr(),
        subtitle: 'honors.detail.step1_subtitle'.tr(),
      ),
      (
        title: 'honors.detail.step2_title'.tr(),
        subtitle: 'honors.detail.step2_subtitle'.tr(),
      ),
      (
        title: 'honors.detail.step3_title'.tr(),
        subtitle: 'honors.detail.step3_subtitle'.tr(),
      ),
      (
        title: 'honors.detail.step4_title'.tr(),
        subtitle: 'honors.detail.step4_subtitle'.tr(),
      ),
    ];

    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'honors.detail.how_it_works'.tr(),
              style: TextStyle(
                color: context.sac.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ...steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final isLast = i == steps.length - 1;
              return _StepItem(
                index: i,
                title: step.title,
                subtitle: step.subtitle,
                categoryColor: categoryColor,
                isLast: isLast,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final Color categoryColor;
  final bool isLast;

  const _StepItem({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.categoryColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number + dotted connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Numbered circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // Dotted line connector
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _DottedLinePainter(
                            color: categoryColor.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Text content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: context.sac.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.sac.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
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

class _DottedLinePainter extends CustomPainter {
  final Color color;

  const _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dotHeight = 4.0;
    const gapHeight = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
          Offset(0, y), Offset(0, math.min(y + dotHeight, size.height)), paint);
      y += dotHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.color != color;
}

// ── Quick Stats Row (ENROLLED) ────────────────────────────────────────────────

class _QuickStatsRow extends ConsumerWidget {
  final int honorId;
  final UserHonor userHonor;
  final Color categoryColor;

  const _QuickStatsRow({
    required this.honorId,
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(honorProgressStatsProvider(honorId));
    final remaining = (stats.total - stats.completed).clamp(0, stats.total);

    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            value: '${stats.completed}',
            label: 'honors.detail.stat_completed'.tr(),
            categoryColor: categoryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            value: '$remaining',
            label: 'honors.detail.stat_pending'.tr(),
            categoryColor: categoryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            value: 'App',
            label: 'honors.detail.stat_mode'.tr(),
            categoryColor: categoryColor,
          ),
        ),
      ],
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String value;
  final String label;
  final Color categoryColor;

  const _StatMiniCard({
    required this.value,
    required this.label,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: categoryColor,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.sac.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requirements Preview Card (ENROLLED) ─────────────────────────────────────

class _RequirementsPreviewCard extends ConsumerWidget {
  final int honorId;
  final int userHonorId;
  final String honorName;
  final Color categoryColor;

  const _RequirementsPreviewCard({
    required this.honorId,
    required this.userHonorId,
    required this.honorName,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userHonorProgressProvider(honorId));

    return progressAsync.when(
      data: (progressList) {
        // Show first 4 requirements
        final preview = progressList.take(4).toList();
        final remaining = (progressList.length - preview.length)
            .clamp(0, progressList.length);

        return _ShadowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTaskEdit01,
                      size: 18,
                      color: categoryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'honors.detail.requirements_label'.tr(),
                        style: TextStyle(
                          color: context.sac.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _CardDivider(),
              ...preview.map((req) => _RequirementPreviewItem(
                    requirement: req,
                    categoryColor: categoryColor,
                  )),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'honors.detail.more_requirements'
                        .tr(namedArgs: {'count': '$remaining'}),
                    style: TextStyle(
                      color: context.sac.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push(
                      RouteNames.honorRequirementsPath(
                        honorId.toString(),
                        userHonorId.toString(),
                        honorName,
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: categoryColor, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'honors.detail.complete_requirements'.tr(),
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 16,
                          color: categoryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _ShadowCard(
        child: Container(
          height: 140,
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: categoryColor,
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RequirementPreviewItem extends StatelessWidget {
  final UserHonorRequirementProgress requirement;
  final Color categoryColor;

  const _RequirementPreviewItem({
    required this.requirement,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool completed = requirement.completed;
    final String text = requirement.text;
    final int number = requirement.requirementNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Check icon
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? AppColors.success.withValues(alpha: 0.12)
                  : context.sac.surfaceVariant,
              border: Border.all(
                color: completed ? AppColors.success : context.sac.border,
                width: 1.5,
              ),
            ),
            child: completed
                ? const HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 13,
                    color: AppColors.success,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$number. $text',
              style: TextStyle(
                color: completed ? context.sac.textTertiary : context.sac.text,
                fontSize: 13,
                height: 1.5,
                decoration: completed ? TextDecoration.lineThrough : null,
                decorationColor: context.sac.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── External Workflow Info (ENROLLED / EXTERNAL) ──────────────────────────────

class _ExternalWorkflowInfoCard extends StatelessWidget {
  final Color categoryColor;
  final Duration animationDelay;

  const _ExternalWorkflowInfoCard({
    required this.categoryColor,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      animate: true,
      animationDelay: animationDelay,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedPdf01,
              color: categoryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'honors.detail.external_mode_title'.tr(),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'honors.detail.external_mode_subtitle'.tr(),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    height: 1.45,
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

// ── Evidence Section (ENROLLED) ───────────────────────────────────────────────

class _EvidenceSection extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final Duration animationDelay;

  const _EvidenceSection({
    required this.userHonor,
    required this.categoryColor,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      animate: true,
      animationDelay: animationDelay,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                size: 18,
                color: categoryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userHonor.hasCompletedFormat
                      ? 'honors.detail.completed_format_ready'.tr()
                      : 'honors.detail.completed_format_missing'.tr(),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (userHonor.images.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: userHonor.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: HonorSignedEvidenceImage(
                      imageUrl: userHonor.images[index],
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      memCacheWidth: 168,
                      memCacheHeight: 168,
                      errorWidget: (_, __, ___) => Container(
                        width: 56,
                        height: 56,
                        color: c.border,
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedImageDelete01,
                          size: 20,
                          color: c.textTertiary,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'honors.detail.general_evidence_count'.tr(
              namedArgs: {'count': '${userHonor.generalEvidenceCount}'},
            ),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Material Download Card ────────────────────────────────────────────────────

class _MaterialDownloadCard extends StatefulWidget {
  final String materialUrl;
  final Color categoryColor;
  final Duration animationDelay;

  const _MaterialDownloadCard({
    required this.materialUrl,
    required this.categoryColor,
    this.animationDelay = Duration.zero,
  });

  @override
  State<_MaterialDownloadCard> createState() => _MaterialDownloadCardState();
}

class _MaterialDownloadCardState extends State<_MaterialDownloadCard> {
  bool _isLaunching = false;

  Future<void> _openMaterial() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    try {
      final uri = Uri.tryParse(widget.materialUrl);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        _showError('honors.detail.material_error'.tr());
        return;
      }
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('honors.detail.material_error'.tr());
      }
    } catch (_) {
      _showError('honors.detail.material_pdf_error'.tr());
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacCard(
      animate: true,
      animationDelay: widget.animationDelay,
      onTap: _isLaunching ? null : _openMaterial,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedPdf01,
              size: 20,
              color: widget.categoryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'honors.detail.study_material'.tr(),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'honors.detail.material_subtitle'.tr(),
                  style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_isLaunching)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.categoryColor,
              ),
            )
          else
            HugeIcon(
              icon: HugeIcons.strokeRoundedDownload01,
              color: widget.categoryColor,
              size: 20,
            ),
        ],
      ),
    );
  }
}

// ── Bottom CTA Bar ────────────────────────────────────────────────────────────

class _BottomCtaBar extends ConsumerWidget {
  final Honor honor;
  final int honorId;
  final UserHonor? userHonor;
  final bool isEnrolled;
  final Color categoryColor;
  final bool userHonorsLoading;
  final AsyncValue<UserHonor?> enrollAsync;

  const _BottomCtaBar({
    required this.honor,
    required this.honorId,
    required this.userHonor,
    required this.isEnrolled,
    required this.categoryColor,
    required this.userHonorsLoading,
    required this.enrollAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          child: isEnrolled
              ? _EnrolledCtaButton(
                  userHonor: userHonor!,
                  honor: honor,
                  categoryColor: categoryColor,
                )
              : userHonorsLoading
                  ? _LoadingCtaButton(categoryColor: categoryColor)
                  : enrollAsync.when(
                      data: (enrolled) {
                        if (enrolled != null) return const SizedBox.shrink();
                        return _EnrollCtaButton(
                          honorId: honorId,
                          categoryColor: categoryColor,
                        );
                      },
                      loading: () =>
                          _LoadingCtaButton(categoryColor: categoryColor),
                      error: (err, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              err.toString().replaceAll('Exception: ', ''),
                              style: const TextStyle(
                                color: AppColors.errorDark,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          _EnrollCtaButton(
                            honorId: honorId,
                            categoryColor: categoryColor,
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

// ── Enroll CTA Button ─────────────────────────────────────────────────────────

class _EnrollCtaButton extends ConsumerStatefulWidget {
  final int honorId;
  final Color categoryColor;

  const _EnrollCtaButton({
    required this.honorId,
    required this.categoryColor,
  });

  @override
  ConsumerState<_EnrollCtaButton> createState() => _EnrollCtaButtonState();
}

class _EnrollCtaButtonState extends ConsumerState<_EnrollCtaButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  Future<void> _onTap() async {
    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.id;
    if (userId == null) return;

    await ref
        .read(honorEnrollmentNotifierProvider.notifier)
        .enrollInHonor(userId, widget.honorId);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final foregroundColor = _heroForegroundColor(context, widget.categoryColor);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.lightImpact();
        _setPressed(true);
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: _onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
        duration: SacMotion.press,
        curve: SacMotion.easeOut,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: widget.categoryColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.categoryColor.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'honors.detail.enroll_cta'.tr(),
            style: TextStyle(
              color: foregroundColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading CTA Button ────────────────────────────────────────────────────────

class _LoadingCtaButton extends StatelessWidget {
  final Color categoryColor;

  const _LoadingCtaButton({required this.categoryColor});

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _heroForegroundColor(context, categoryColor);

    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: foregroundColor,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

// ── Enrolled CTA Button ───────────────────────────────────────────────────────

class _EnrolledCtaButton extends StatelessWidget {
  final UserHonor userHonor;
  final Honor honor;
  final Color categoryColor;

  const _EnrolledCtaButton({
    required this.userHonor,
    required this.honor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final actionForegroundColor = _heroForegroundColor(context, categoryColor);

    // Under review — disabled
    if (userHonor.isUnderReview) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accent, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
                icon: HugeIcons.strokeRoundedHourglass,
                size: 16,
                color: AppColors.accent),
            const SizedBox(width: 8),
            Text(
              'honors.detail.under_review_cta'.tr(),
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // Approved — status lives in the body, not a fake CTA.
    if (userHonor.isCompleted) {
      return const SizedBox.shrink();
    }

    if (userHonor.completionMode == HonorCompletionMode.undecided) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.sac.border, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          'honors.detail.select_mode_cta'.tr(),
          style: TextStyle(
            color: context.sac.textSecondary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final isInApp = userHonor.completionMode == HonorCompletionMode.inApp;
    final label = isInApp
        ? 'honors.detail.continue_requirements_cta'.tr()
        : 'honors.detail.external_flow_cta'.tr();

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        if (isInApp) {
          context.push(
            RouteNames.honorRequirementsPath(
              honor.id.toString(),
              userHonor.id.toString(),
              honor.name,
            ),
          );
        } else {
          context.push(
            RouteNames.honorEvidencePath(
              honor.id.toString(),
              userHonor.id.toString(),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: categoryColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: categoryColor.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: actionForegroundColor,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ── Shadow Card ───────────────────────────────────────────────────────────────

class _ShadowCard extends StatelessWidget {
  final Widget child;

  const _ShadowCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
