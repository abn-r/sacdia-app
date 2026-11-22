import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

import '../../domain/entities/certificate_import_item.dart';
import '../utils/import_formatters.dart';
import 'import_catalog_images.dart';

/// How the subtitle of an [ImportItemRow] reads.
enum ImportRowTone { normal, warning, error }

/// The subtitle of a review row: honor category (or club type) and the date,
/// each replaced by what is missing when it is not there yet. [missing] is
/// true when something was replaced; [attention] also covers a date to double
/// check. The row tints its subtitle on [attention].
({String text, bool missing, bool attention}) importReviewSubtitle(
    CertificateImportItem item) {
  final parts = <String>[];
  var missing = false;
  void need(String key) {
    parts.add(key.tr());
    missing = true;
  }

  final date = item.completedAt;
  final dateText = date == null ? null : importShortDate(date);
  switch (item.type) {
    case CertificateImportItemType.unknown:
      need('certificate_import.item.pick_type');
    case CertificateImportItemType.honor:
      final category = item.honor?.categoryName;
      if (item.honorId == null) {
        need('certificate_import.item.pick_honor');
      } else if (category != null && category.isNotEmpty) {
        parts.add(category);
      }
      if (dateText != null) {
        parts.add(dateText);
      } else {
        need('certificate_import.item.missing_date');
      }
    case CertificateImportItemType.clazz:
      final club = item.classRef?.clubTypeName;
      if (item.classId == null) {
        need('certificate_import.item.pick_class');
      } else if (club != null && club.isNotEmpty) {
        parts.add(club);
      }
      if (dateText != null) {
        parts.add('certificate_import.item.investiture'
            .tr(namedArgs: {'date': dateText}));
      } else {
        need('certificate_import.item.missing_date');
      }
  }
  if (item.missing.length == 1 &&
      item.missing.single == CertificateImportMissing.name) {
    need('certificate_import.item.missing_name');
  }
  final reviewDate = !missing && item.needsDateReview;
  if (reviewDate) parts.add('certificate_import.item.review_date'.tr());
  return (
    text: parts.join(' · '),
    missing: missing,
    attention: missing || reviewDate,
  );
}

/// "Falta" (warning) or "Lista" (ok) chip of a review row: text plus icon,
/// never color alone.
class ImportReadyChip extends StatelessWidget {
  const ImportReadyChip({super.key, required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    return ready
        ? SacBadge.success(
            label: 'certificate_import.item.ready'.tr(),
            icon: HugeIcons.strokeRoundedTick02,
          )
        : SacBadge.warning(
            label: 'certificate_import.item.chip_missing'.tr(),
            icon: HugeIcons.strokeRoundedAlert02,
          );
  }
}

/// One imported row, compact: the honor badge (or the class logo), the title,
/// one line of context and an optional trailing widget. Lives inside a
/// `SacGroupedSection`. [onTap] null makes it read-only (no chevron).
class ImportItemRow extends StatelessWidget {
  const ImportItemRow({
    super.key,
    required this.item,
    required this.subtitle,
    this.tone = ImportRowTone.normal,
    this.trailing,
    this.onTap,
  });

  final CertificateImportItem item;
  final String subtitle;
  final ImportRowTone tone;

  /// Replaces the chevron (a chip).
  final Widget? trailing;
  final VoidCallback? onTap;

  static const double leadingSize = 40;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isClass = item.type == CertificateImportItemType.clazz;
    final title = item.displayName ?? 'certificate_import.item.unnamed'.tr();
    final subtitleColor = switch (tone) {
      ImportRowTone.normal => c.textSecondary,
      ImportRowTone.warning => c.onWarningContainer,
      ImportRowTone.error => c.onErrorContainer,
    };
    final end = trailing ??
        (onTap == null
            ? null
            : HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 18,
                color: c.textTertiary,
              ));
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          children: [
            ExcludeSemantics(
              child: isClass
                  ? ImportClassLogo(
                      assetCode:
                          item.classRef?.assetCode ?? item.classAssetCode,
                      name: item.classRef?.name,
                      size: leadingSize,
                    )
                  : ImportHonorBadge(
                      imageUrl: item.honor?.imageUrl,
                      size: leadingSize,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        subtitle,
                        maxLines: tone == ImportRowTone.error ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          height: 1.35,
                          color: subtitleColor,
                        ),
                      ),
                      if (item.honorSuggested && !isClass)
                        SacBadge(
                          key: const ValueKey('import-row-suggested'),
                          label: 'certificate_import.editor.suggested'.tr(),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (end != null) ...[const SizedBox(width: 8), end],
          ],
        ),
      ),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      child: onTap == null
          ? content
          : SacInkWell(
              onTap: onTap,
              pressedScale: SacMotion.rowPressScale,
              child: content,
            ),
    );
  }
}
