import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/club_type.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_badge_image.dart';

import '../../domain/entities/certificate_import_item.dart';

/// One imported row. The whole card opens the editor ([onEdit]).
///
/// Shows catalog names, never ids or confidence percentages. What is missing
/// is spelled out in the badge ("Falta la fecha"), and a date read with low
/// confidence adds "Revisa la fecha" (D5).
class CertificateImportItemCard extends StatelessWidget {
  const CertificateImportItemCard({
    super.key,
    required this.item,
    this.onEdit,
    this.onResubmit,
    this.onViewProof,
    this.proofPage,
  });

  final CertificateImportItem item;
  final VoidCallback? onEdit;
  final VoidCallback? onResubmit;

  /// Opens the proof at this row. Null hides the button (no file to show).
  final VoidCallback? onViewProof;

  /// Page to name on the proof button ("pág. 2"); null hides the suffix.
  final int? proofPage;

  bool get _isRejected => item.isRejected || item.rejectionReason != null;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final theme = Theme.of(context).textTheme;
    final isHonor = item.type == CertificateImportItemType.honor;
    final title = item.displayName ?? 'certificate_import.item.unnamed'.tr();
    final detected = item.detectedName?.trim() ?? '';
    final catalogName = isHonor ? item.honor?.name : item.classRef?.name;
    final showRead = catalogName != null &&
        detected.isNotEmpty &&
        detected.toLowerCase() != catalogName.toLowerCase();
    final subtitle = isHonor ? item.honor?.categoryName : _clubTypeName;
    final date = item.completedAt ?? item.detectedDate;
    final dateText =
        date == null ? null : DateFormat('dd/MM/yyyy').format(date);
    final tail = [
      if (dateText != null)
        isHonor
            ? dateText
            : 'certificate_import.item.investiture'
                .tr(namedArgs: {'date': dateText}),
      if (isHonor && item.instructor != null) item.instructor!.displayName,
    ].join(' · ');

    return SacCard(
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SacStateSwap(
                child: KeyedSubtree(
                  key: ValueKey('leading-${item.honorId}-${item.classId}'),
                  child: _leading(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty)
                      Text(subtitle,
                          style: theme.bodySmall
                              ?.copyWith(color: c.textSecondary)),
                    if (showRead)
                      Text(
                        'certificate_import.item.read_as'
                            .tr(namedArgs: {'text': detected}),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.bodySmall?.copyWith(color: c.textTertiary),
                      ),
                    if (tail.isNotEmpty)
                      Text(tail,
                          style: theme.bodySmall
                              ?.copyWith(color: c.textSecondary)),
                    if (item.needsDateReview) const _DateReviewHint(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SacStateSwap(
            child: Align(
              key: ValueKey(_statusLabel),
              alignment: Alignment.centerLeft,
              child: _statusBadge(),
            ),
          ),
          if (item.rejectionReason != null) ...[
            const SizedBox(height: 10),
            Text(
              item.isPendingAdministrativePeriod
                  ? 'certificate_import.item.period_pending'.tr()
                  : item.rejectionReason!,
              style: theme.bodySmall?.copyWith(
                color: c.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (item.isGuiaMayorBase) ...[
            const SizedBox(height: 8),
            Text('certificate_import.item.gm01_replace'.tr(),
                style: theme.bodySmall?.copyWith(color: c.textSecondary)),
          ],
          if (item.isInstitutionalClass) ...[
            const SizedBox(height: 8),
            Text('certificate_import.item.institutional'.tr(),
                style: theme.bodySmall?.copyWith(color: c.textSecondary)),
          ],
          if (onViewProof != null) ...[
            const SizedBox(height: 6),
            SacButton.ghost(
              text: proofPage == null
                  ? 'certificate_import.item.view_proof'.tr()
                  : 'certificate_import.item.view_proof_page'
                      .tr(namedArgs: {'page': '$proofPage'}),
              icon: HugeIcons.strokeRoundedFile01,
              onPressed: onViewProof,
            ),
          ],
          if (onResubmit != null && _isRejected) ...[
            const SizedBox(height: 10),
            SacButton.outline(
              text: 'certificate_import.item.fix_resubmit'.tr(),
              onPressed: onResubmit,
            ),
          ],
        ],
      ),
    );
  }

  String? get _clubTypeName => item.classRef?.clubTypeName;

  bool get _isResubmitted =>
      !_isRejected && item.status == CertificateImportItemStatus.resubmitted;

  String get _statusLabel {
    if (_isRejected) return 'certificate_import.item.rejected'.tr();
    if (_isResubmitted) return 'certificate_import.item.resubmitted'.tr();
    final missing = item.missing;
    if (missing.isEmpty) return 'certificate_import.item.ready'.tr();
    if (missing.length > 1) {
      return 'certificate_import.item.missing_many'
          .tr(namedArgs: {'count': '${missing.length}'});
    }
    return switch (missing.single) {
      CertificateImportMissing.date =>
        'certificate_import.item.missing_date'.tr(),
      CertificateImportMissing.honor =>
        'certificate_import.item.missing_honor'.tr(),
      CertificateImportMissing.clazz =>
        'certificate_import.item.missing_class'.tr(),
      CertificateImportMissing.type =>
        'certificate_import.item.missing_type'.tr(),
      CertificateImportMissing.name =>
        'certificate_import.item.missing_name'.tr(),
    };
  }

  Widget _statusBadge() {
    final label = _statusLabel;
    if (_isRejected) return SacBadge.error(label: label);
    // Resent and waiting for the reviewer: not "ready", not done.
    if (_isResubmitted) return SacBadge.warning(label: label);
    return item.isComplete
        ? SacBadge.success(label: label)
        : SacBadge.warning(label: label);
  }

  Widget _leading(BuildContext context) {
    final c = context.sac;
    const size = 40.0;
    if (item.type == CertificateImportItemType.honor && item.honorId != null) {
      return HonorBadgeImage(
        imageUrl: null,
        width: size,
        height: size,
        fallbackColor: c.textSecondary,
        fallbackBackgroundColor: c.surfaceVariant,
      );
    }
    final logo =
        item.type == CertificateImportItemType.clazz && item.classId != null
            ? clubLogoAssetFromName(_clubTypeName)
            : null;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: Center(
          child: logo == null
              ? HugeIcon(
                  icon: HugeIcons.strokeRoundedHelpCircle,
                  color: c.textSecondary,
                  size: 22,
                )
              : Image.asset(
                  logo,
                  width: 26,
                  height: 26,
                  errorBuilder: (_, __, ___) => HugeIcon(
                    icon: HugeIcons.strokeRoundedUserGroup,
                    color: c.textSecondary,
                    size: 22,
                  ),
                ),
        ),
      ),
    );
  }
}

/// "Revisa la fecha": warning dot plus ink-colored text (never the raw
/// warning color on a light surface).
class _DateReviewHint extends StatelessWidget {
  const _DateReviewHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: context.sac.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'certificate_import.item.review_date'.tr(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.accentDark,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
