import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pdf_viewer.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/presentation/utils/evidence_url.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_info_parts.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_rejection_card.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_signed_evidence_image.dart';

/// Most general evidence files an external honor accepts.
const int kHonorMaxGeneralEvidence = 10;

/// "Formato y evidencias" tab of an honor worked outside the app.
///
/// Three cards: the completed format (with "Reemplazar" while it can still
/// change), the general evidence grid with its "n/10" count and "Agregar"
/// cell, and the study material. A rejection notice sits on top when the
/// reviewer rejected the honor. The screen owns uploading and deleting; this
/// widget only reports taps.
class HonorExternalWorkTab extends StatelessWidget {
  const HonorExternalWorkTab({
    super.key,
    required this.userHonor,
    required this.honorName,
    required this.materialUrl,
    required this.paintColor,
    required this.accent,
    required this.onUploadCompletedFormat,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
    required this.onOpenDocument,
  });

  final UserHonor userHonor;
  final String honorName;
  final String? materialUrl;

  /// Category paint color (icon wells).
  final Color paintColor;

  /// Color of icons and links on the tint (band color in light mode).
  final Color accent;
  final VoidCallback onUploadCompletedFormat;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url, List<String> imageUrls, int initialIndex)
      onViewEvidence;
  final void Function(String url) onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasDocument = userHonor.hasCompletedFormat;
    final canEdit = userHonor.canSubmit;
    final documentUrl = userHonor.document;
    final rejected = userHonor.validationStatus.toUpperCase() == 'REJECTED';
    final material = materialUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rejected) ...[
          HonorRejectionCard(reason: userHonor.rejectionReason),
          const SizedBox(height: 12),
        ],
        SacCard(
          key: const ValueKey('external-format-card'),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: HonorInfoRow(
                  key: const ValueKey('external-format-row'),
                  icon: hasDocument
                      ? HugeIcons.strokeRoundedCheckmarkCircle02
                      : HugeIcons.strokeRoundedUpload01,
                  well: hasDocument
                      ? c.successContainer
                      : paintColor.withValues(alpha: 0.12),
                  iconColor: hasDocument ? c.onSuccessContainer : accent,
                  title: 'honors.evidence.completed_format_title'.tr(),
                  subtitle: hasDocument
                      ? 'honors.evidence.completed_format_uploaded'.tr()
                      : 'honors.evidence.completed_format_missing'.tr(),
                  onTap: hasDocument
                      ? (documentUrl == null
                          ? null
                          : () => onOpenDocument(documentUrl))
                      : (canEdit ? onUploadCompletedFormat : null),
                ),
              ),
              if (hasDocument && canEdit)
                SacButton.text(
                  key: const ValueKey('external-format-replace'),
                  text: 'honors.evidence.replace_completed_format'.tr(),
                  color: accent,
                  onPressed: onUploadCompletedFormat,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SacCard(
          key: const ValueKey('external-evidence-card'),
          child: _EvidenceSection(
            userHonor: userHonor,
            canEdit: canEdit,
            accent: accent,
            onAddEvidence: onAddEvidence,
            onDeleteEvidence: onDeleteEvidence,
            onViewEvidence: onViewEvidence,
          ),
        ),
        if (material != null && material.isNotEmpty) ...[
          const SizedBox(height: 12),
          SacCard(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: HonorInfoRow(
              key: const ValueKey('external-material-row'),
              icon: HugeIcons.strokeRoundedPdf01,
              well: paintColor.withValues(alpha: 0.12),
              iconColor: accent,
              title: 'honors.evidence.material_title'.tr(),
              subtitle: 'honors.evidence.material_subtitle'.tr(),
              onTap: () => SacPdfViewer.show(
                context,
                pdfSource: material,
                title: honorName,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _EvidenceSection extends StatelessWidget {
  const _EvidenceSection({
    required this.userHonor,
    required this.canEdit,
    required this.accent,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
  });

  final UserHonor userHonor;
  final bool canEdit;
  final Color accent;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url, List<String> imageUrls, int initialIndex)
      onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;
    final images = userHonor.images;
    final showAddCell =
        canEdit && userHonor.generalEvidenceCount < kHonorMaxGeneralEvidence;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'honors.evidence.general_section_title'.tr(),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
            Text(
              '${userHonor.generalEvidenceCount}/$kHonorMaxGeneralEvidence',
              key: const ValueKey('external-evidence-count'),
              style: text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'honors.evidence.general_empty_subtitle'.tr(),
          style: text.bodySmall?.copyWith(color: c.textSecondary),
        ),
        if (images.isNotEmpty || showAddCell) ...[
          const SizedBox(height: 12),
          _EvidenceGrid(
            images: images,
            showAddCell: showAddCell,
            canDelete: canEdit,
            accent: accent,
            onAddEvidence: onAddEvidence,
            onDeleteEvidence: onDeleteEvidence,
            onViewEvidence: onViewEvidence,
          ),
        ],
      ],
    );
  }
}

class _EvidenceGrid extends StatelessWidget {
  const _EvidenceGrid({
    required this.images,
    required this.showAddCell,
    required this.canDelete,
    required this.accent,
    required this.onAddEvidence,
    required this.onDeleteEvidence,
    required this.onViewEvidence,
  });

  final List<String> images;
  final bool showAddCell;
  final bool canDelete;
  final Color accent;
  final VoidCallback onAddEvidence;
  final void Function(String imageUrl) onDeleteEvidence;
  final void Function(String url, List<String> imageUrls, int initialIndex)
      onViewEvidence;

  @override
  Widget build(BuildContext context) {
    final itemCount = images.length + (showAddCell ? 1 : 0);

    return GridView.builder(
      padding: EdgeInsets.zero,
      // shrinkWrap OK: lives inside a scroll view's Column (non-scrollable).
      // Item count is bounded by the evidence files a member uploads (max 10).
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
        if (index == images.length && showAddCell) {
          return _AddEvidenceCell(accent: accent, onTap: onAddEvidence);
        }

        final imageUrl = images[index];
        return _EvidenceThumbnail(
          imageUrl: imageUrl,
          canDelete: canDelete,
          onDelete: () => onDeleteEvidence(imageUrl),
          onTap: () {
            final carouselImages = images
                .where((url) =>
                    !isPdfEvidenceUrl(url) && isFetchableEvidenceUrl(url))
                .toList();
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

class _AddEvidenceCell extends StatefulWidget {
  const _AddEvidenceCell({required this.accent, required this.onTap});

  final Color accent;
  final VoidCallback onTap;

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
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'honors.evidence.add_cell_label'.tr(),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: GestureDetector(
        key: const ValueKey('external-add-evidence'),
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
          child: Container(
            decoration: BoxDecoration(
              color: context.sac.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedAdd01,
                  color: widget.accent,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  'honors.evidence.add_cell_label'.tr(),
                  style: text.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: widget.accent,
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

class _EvidenceThumbnail extends StatelessWidget {
  const _EvidenceThumbnail({
    required this.imageUrl,
    required this.canDelete,
    required this.onDelete,
    required this.onTap,
  });

  final String imageUrl;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  bool get _isPdf => isPdfEvidenceUrl(imageUrl);

  /// A raw storage key cannot be downloaded: show a calm placeholder instead
  /// of a broken image.
  bool get _isUnavailable => !isFetchableEvidenceUrl(imageUrl);

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final text = Theme.of(context).textTheme;

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
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_isPdf)
              Container(
                color: c.errorContainer,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedPdf01,
                      color: c.onErrorContainer,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'PDF',
                      style: text.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              )
            else if (_isUnavailable)
              Container(
                color: c.surfaceVariant,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedFile01,
                  color: c.textTertiary,
                  size: 24,
                ),
              )
            else
              HonorSignedEvidenceImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                placeholder: (_, __) => Container(
                  color: c.surfaceVariant,
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: FittedBox(child: SacLoadingSmall()),
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: c.surfaceVariant,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedImageDelete01,
                    color: c.textTertiary,
                    size: 24,
                  ),
                ),
              ),
            if (!_isPdf && !_isUnavailable)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: c.success,
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
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
