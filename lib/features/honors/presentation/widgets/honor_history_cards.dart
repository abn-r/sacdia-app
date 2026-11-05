import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_image_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/utils/evidence_url.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_signed_evidence_image.dart';

String? _validatorRoleLabel(UserHonor userHonor) {
  final roleName = honorTrimmedOrNull(userHonor.validatedByRoleName);
  final roleLabel = honorTrimmedOrNull(userHonor.validatedByRoleLabel);

  if (roleLabel == null ||
      roleLabel.toLowerCase().startsWith('role:') ||
      roleLabel == roleName) {
    return _humanizeRoleName(roleName);
  }

  return roleLabel;
}

String? _humanizeRoleName(String? roleName) {
  final normalized = honorTrimmedOrNull(roleName);
  if (normalized == null) return null;

  return normalized
      .replaceAll(RegExp('[-_]'), ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _formatHistoryDate(BuildContext context, DateTime? date) {
  if (date == null) return 'honors.detail.history_not_available'.tr();
  return SacDateFormatter.dateTimeShort(date);
}

String? honorTrimmedOrNull(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
    SacSnackBar.show(context, 'honors.detail.open_file_error'.tr(),
        isError: true);
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    SacSnackBar.show(context, 'honors.detail.open_file_error'.tr(),
        isError: true);
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
  if (isPdfEvidenceUrl(url)) {
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

class HonorValidationHistoryCard extends StatelessWidget {
  final UserHonor userHonor;
  final Duration animationDelay;

  const HonorValidationHistoryCard({
    super.key,
    required this.userHonor,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final validator = honorTrimmedOrNull(userHonor.validatedByName) ??
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
        key: const ValueKey('history-validated-by'),
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
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = highlight ? c.onSuccessContainer : c.textTertiary;
    final well = highlight ? c.successContainer : c.surfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Round well with a centered icon, like the celebration card.
          // Without the alignment the icon stretches to fill the well.
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: well, shape: BoxShape.circle),
            child: HugeIcon(icon: icon, size: 18, color: accent),
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
                    fontSize: SacFontSize.labelSmall,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    color: context.sac.text,
                    fontSize: SacFontSize.titleSmall,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if (honorTrimmedOrNull(detail) != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: TextStyle(
                      color: context.sac.textSecondary,
                      fontSize: SacFontSize.bodySmall,
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

class HonorExternalWorkHistoryCard extends StatelessWidget {
  final UserHonor userHonor;
  final Color categoryColor;
  final Duration animationDelay;

  const HonorExternalWorkHistoryCard({
    super.key,
    required this.userHonor,
    required this.categoryColor,
    this.animationDelay = Duration.zero,
  });

  @override
  Widget build(BuildContext context) {
    final imageEvidenceUrls = userHonor.images
        .where((url) => !isPdfEvidenceUrl(url))
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

            if (isPdfEvidenceUrl(url)) {
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

class HonorRequirementsHistoryCard extends StatelessWidget {
  final AsyncValue<List<UserHonorRequirementProgress>> progressAsync;
  final Color categoryColor;
  final Duration animationDelay;

  const HonorRequirementsHistoryCard({
    super.key,
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
                    fontSize: SacFontSize.bodyMedium,
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
          child: SacLoading(color: categoryColor),
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
            fontSize: SacFontSize.bodyMedium,
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
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceVariant,
            shape: BoxShape.circle,
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
                  fontSize: SacFontSize.bodyMedium,
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
    final response = honorTrimmedOrNull(requirement.textResponse);
    final notes = honorTrimmedOrNull(requirement.notes);
    final imageEvidenceUrls = requirement.evidences
        .where((evidence) =>
            evidence.evidenceType == EvidenceType.image ||
            (!isPdfEvidenceUrl(evidence.url) &&
                _isImageEvidenceUrl(evidence.url)))
        .map((evidence) => evidence.url)
        .toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                      ? context.sac.successContainer
                      : categoryColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${requirement.requirementNumber}',
                  style: TextStyle(
                    color: requirement.completed
                        ? context.sac.onSuccessContainer
                        : categoryColor,
                    fontSize: SacFontSize.bodySmall,
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
                    fontSize: SacFontSize.bodyMedium,
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
                    ? context.sac.onSuccessContainer
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
                fontSize: SacFontSize.labelSmall,
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
                fontSize: SacFontSize.bodySmall,
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
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: context.sac.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: context.sac.textTertiary,
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: context.sac.textSecondary,
              fontSize: SacFontSize.bodyMedium,
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
        honorTrimmedOrNull(evidence.filename) ?? _fileNameFromUrl(evidence.url);
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
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
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
                      fontSize: SacFontSize.bodyMedium,
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
                      fontSize: SacFontSize.labelSmall,
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
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: context.sac.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusXS),
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
                  alignment: Alignment.center,
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
                  fontSize: SacFontSize.bodyMedium,
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
