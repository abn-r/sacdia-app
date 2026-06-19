import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';

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

// ── Design tokens ─────────────────────────────────────────────────────────────

// Note: background, surface, text, and border colors are resolved at runtime
// via context.sac.* to support light and dark themes. See SacColors extension.
const _kScreenPad = 20.0;
const _kSectionGap = 24.0;
const _kHeroHeight = 300.0;

// ── Label helpers ─────────────────────────────────────────────────────────────

bool _isLightColor(Color color) {
  return ThemeData.estimateBrightnessForColor(color) == Brightness.light;
}

Color _paintColorForCategory(Color categoryColor, Color categoryAccentColor) {
  return _isLightColor(categoryColor) ? categoryAccentColor : categoryColor;
}

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
    final categoryAccentColor = getCategoryAccentColor(
      categoryId: honor.categoryId,
      categoryName: honor.categoryName ?? categoryName,
    );
    final categoryPaintColor =
        _paintColorForCategory(categoryColor, categoryAccentColor);
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
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('honors.work_mode.confirm_title'.tr()),
        content: Text(_completionModeConfirmationMessageKey(mode).tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}

// ── Hero Section ───────────────────────────────────────────────────────────────

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

class _HeroSectionState extends ConsumerState<_HeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _badgeScale;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _badgeScale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _progressValue = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Delay slightly so the hero renders first
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

    return Container(
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
                scale: _badgeScale,
                child: widget.isEnrolled
                    ? _ProgressBadge(
                        honor: widget.honor,
                        categoryColor: widget.categoryColor,
                        progressValue: _progressValue,
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
                  animation: _progressValue,
                  builder: (context, _) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progressValue.value * progressPercent,
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
                  label: _completionModeLabel(widget.userHonor!.completionMode),
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
    _controller.forward();
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

  Future<void> _showChangeWorkModeSheet(
    HonorCompletionMode currentMode,
  ) async {
    final selectedMode = await showModalBottomSheet<HonorCompletionMode>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: HonorWorkModeSelector(
            categoryColor: widget.categoryColor,
            isLoading: widget.modeActionState.isLoading,
            onSelected: (mode) => Navigator.of(sheetContext).pop(mode),
          ),
        );
      },
    );

    if (!mounted || selectedMode == null || selectedMode == currentMode) {
      return;
    }

    widget.onSelectCompletionMode(selectedMode);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEnrolled) {
      final userHonor = widget.userHonor!;
      final completionMode = userHonor.completionMode;
      final canChangeCompletionMode = userHonor.canSubmit;

      if (userHonor.isCompleted) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: _kSectionGap),
            _animated(
              0,
              _CompletedHonorHistorySection(
                honorId: widget.honorId,
                userHonor: userHonor,
                categoryColor: widget.categoryColor,
              ),
            ),
            const SizedBox(height: 120),
          ],
        );
      }

      if (completionMode == HonorCompletionMode.undecided) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: _kSectionGap),
            _animated(
              0,
              canChangeCompletionMode
                  ? HonorWorkModeSelector(
                      categoryColor: widget.categoryColor,
                      isLoading: widget.modeActionState.isLoading,
                      onSelected: widget.onSelectCompletionMode,
                    )
                  : _LockedWorkModeCard(
                      userHonor: userHonor,
                      categoryColor: widget.categoryColor,
                    ),
            ),
            const SizedBox(height: 120),
          ],
        );
      }

      if (completionMode == HonorCompletionMode.external) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: _kSectionGap),
            _animated(
              0,
              _ExternalWorkflowInfoCard(
                categoryColor: widget.categoryColor,
              ),
            ),
            if (canChangeCompletionMode) ...[
              const SizedBox(height: 12),
              _animated(
                1,
                _ChangeWorkModeButton(
                  categoryColor: widget.categoryColor,
                  isLoading: widget.modeActionState.isLoading,
                  onPressed: () => _showChangeWorkModeSheet(completionMode),
                ),
              ),
            ],
            if (widget.honor.materialUrl != null &&
                widget.honor.materialUrl!.isNotEmpty) ...[
              const SizedBox(height: _kSectionGap),
              _animated(
                2,
                _MaterialDownloadCard(
                  materialUrl: widget.honor.materialUrl!,
                  categoryColor: widget.categoryColor,
                ),
              ),
            ],
            const SizedBox(height: _kSectionGap),
            _animated(
              3,
              _EvidenceSection(
                userHonor: userHonor,
                honorId: widget.honorId,
                categoryColor: widget.categoryColor,
              ),
            ),
            const SizedBox(height: 120),
          ],
        );
      }

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
                onPressed: () => _showChangeWorkModeSheet(completionMode),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ValidationHistoryCard(
          userHonor: userHonor,
          categoryColor: categoryColor,
        ),
        if (showExternalHistory) ...[
          const SizedBox(height: _kSectionGap),
          _ExternalWorkHistoryCard(
            userHonor: userHonor,
            categoryColor: categoryColor,
          ),
        ],
        if (showRequirementsHistory) ...[
          const SizedBox(height: _kSectionGap),
          _RequirementsHistoryCard(
            progressAsync: progressAsync!,
            categoryColor: categoryColor,
          ),
        ],
      ],
    );
  }
}

class _ValidationHistoryCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;

  const _ValidationHistoryCard({
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final validator = _trimmedOrNull(userHonor.validatedByName) ??
        'honors.detail.history_not_available'.tr();
    final validatorRole = _validatorRoleLabel(userHonor);

    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    size: 24,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'honors.detail.validation_history_title'.tr(),
                        style: TextStyle(
                          color: context.sac.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'honors.detail.validation_history_subtitle'.tr(),
                        style: TextStyle(
                          color: context.sac.textSecondary,
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _HistoryInfoRow(
              icon: HugeIcons.strokeRoundedTaskEdit01,
              label: 'honors.detail.history_mode_label'.tr(),
              value: _completionModeHistoryLabel(userHonor),
              categoryColor: categoryColor,
            ),
            _CardDivider(),
            _HistoryInfoRow(
              icon: HugeIcons.strokeRoundedCalendar01,
              label: 'honors.detail.history_registered_label'.tr(),
              value: _formatHistoryDate(context, userHonor.date),
              categoryColor: categoryColor,
            ),
            _CardDivider(),
            _HistoryInfoRow(
              icon: HugeIcons.strokeRoundedClock01,
              label: 'honors.detail.history_submitted_label'.tr(),
              value: _formatHistoryDate(context, userHonor.submittedAt),
              categoryColor: categoryColor,
            ),
            _CardDivider(),
            _HistoryInfoRow(
              icon: HugeIcons.strokeRoundedCheckmarkCircle02,
              label: 'honors.detail.history_validated_label'.tr(),
              value: _formatHistoryDate(context, userHonor.validatedAt),
              categoryColor: AppColors.success,
            ),
            _CardDivider(),
            _HistoryInfoRow(
              icon: HugeIcons.strokeRoundedUser,
              label: 'honors.detail.history_validated_by_label'.tr(),
              value: validator,
              detail: validatorRole,
              categoryColor: categoryColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryInfoRow extends StatelessWidget {
  final HugeIconData icon;
  final String label;
  final String value;
  final String? detail;
  final Color categoryColor;

  const _HistoryInfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.10),
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

  const _ExternalWorkHistoryCard({
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final imageEvidenceUrls = userHonor.images
        .where((url) => !_isPdfEvidenceUrl(url))
        .toList(growable: false);

    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
      ),
    );
  }
}

class _RequirementsHistoryCard extends StatelessWidget {
  final AsyncValue<List<UserHonorRequirementProgress>> progressAsync;
  final Color categoryColor;

  const _RequirementsHistoryCard({
    required this.progressAsync,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return progressAsync.when(
      data: (progressList) {
        return _ShadowCard(
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                            bottom:
                                entry.key == progressList.length - 1 ? 0 : 12,
                          ),
                          child: _RequirementHistoryItem(
                            requirement: entry.value,
                            categoryColor: categoryColor,
                          ),
                        ),
                      ),
              ],
            ),
          ),
        );
      },
      loading: () => _ShadowCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: categoryColor,
            ),
          ),
        ),
      ),
      error: (_, __) => _ShadowCard(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'honors.detail.requirements_history_error'.tr(),
            style: TextStyle(
              color: context.sac.textSecondary,
              fontSize: 13,
              height: 1.45,
            ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: HugeIcon(icon: icon, size: 21, color: categoryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.sac.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: context.sac.textSecondary,
                  fontSize: 12,
                  height: 1.45,
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
    final foreground = isLoading ? context.sac.textTertiary : categoryColor;

    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: categoryColor.withValues(alpha: isLoading ? 0.12 : 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedRefresh,
              size: 18,
              color: foreground,
            ),
            const SizedBox(width: 8),
            Text(
              'honors.detail.change_work_mode_cta'.tr(),
              style: TextStyle(
                color: foreground,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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

  const _ExternalWorkflowInfoCard({required this.categoryColor});

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.12),
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
                      color: context.sac.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'honors.detail.external_mode_subtitle'.tr(),
                    style: TextStyle(
                      color: context.sac.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Evidence Section (ENROLLED) ───────────────────────────────────────────────

class _EvidenceSection extends StatelessWidget {
  final UserHonor userHonor;
  final int honorId;
  final Color categoryColor;

  const _EvidenceSection({
    required this.userHonor,
    required this.honorId,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                Text(
                  userHonor.hasCompletedFormat
                      ? 'honors.detail.completed_format_ready'.tr()
                      : 'honors.detail.completed_format_missing'.tr(),
                  style: TextStyle(
                    color: context.sac.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Thumbnail row
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
                          color: context.sac.border,
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedImageDelete01,
                            size: 20,
                            color: context.sac.textTertiary,
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
                color: context.sac.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Evidence button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(
                  RouteNames.honorEvidencePath(
                    honorId.toString(),
                    userHonor.id.toString(),
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
                      'honors.detail.external_flow_cta'.tr(),
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
          ],
        ),
      ),
    );
  }
}

// ── Material Download Card ────────────────────────────────────────────────────

class _MaterialDownloadCard extends StatefulWidget {
  final String materialUrl;
  final Color categoryColor;

  const _MaterialDownloadCard({
    required this.materialUrl,
    required this.categoryColor,
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
    return _ShadowCard(
      child: GestureDetector(
        onTap: _openMaterial,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.categoryColor.withValues(alpha: 0.10),
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
                        color: context.sac.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'honors.detail.material_subtitle'.tr(),
                      style: TextStyle(
                        color: context.sac.textTertiary,
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
        ),
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

class _EnrollCtaButtonState extends ConsumerState<_EnrollCtaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressScale = _pressController;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    await _pressController.reverse();
    await _pressController.forward();
    HapticFeedback.mediumImpact();

    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.id;
    if (userId == null) return;

    await ref
        .read(honorEnrollmentNotifierProvider.notifier)
        .enrollInHonor(userId, widget.honorId);
  }

  @override
  Widget build(BuildContext context) {
    final foregroundColor = _heroForegroundColor(context, widget.categoryColor);

    return ScaleTransition(
      scale: _pressScale,
      child: GestureDetector(
        onTap: _onTap,
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

    // Approved — completed state
    if (userHonor.isCompleted) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                size: 18,
                color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              'honors.detail.completed_cta'.tr(),
              style: const TextStyle(
                color: AppColors.success,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
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
