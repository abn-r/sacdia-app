import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/requirement_evidence.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/honor_signed_evidence_image.dart';

/// Size of an evidence thumbnail and of the "Agregar" tile.
const double kHonorEvidenceTileSize = 72;

/// Evidence of ONE requirement: a caption, the files already attached as
/// thumbnails (PDFs as an icon tile) and an "Agregar" tile.
///
/// Uploads and deletions go to the server right away; they are not part of
/// any pending edit. [onChanged] runs after either succeeds, so the caller
/// can bring a parent's completion in step. With [enabled] false (under
/// review) it only shows what is there.
class HonorRequirementEvidence extends ConsumerStatefulWidget {
  const HonorRequirementEvidence({
    super.key,
    required this.honorId,
    required this.requirementId,
    required this.evidences,
    required this.paintColor,
    required this.enabled,
    this.caption,
    this.onChanged,
  });

  final int honorId;
  final int requirementId;
  final List<RequirementEvidence> evidences;

  /// Category paint (the dashed "Agregar" tile).
  final Color paintColor;
  final bool enabled;

  /// Overrides the default "Evidencia · obligatoria" caption.
  final String? caption;
  final VoidCallback? onChanged;

  @override
  ConsumerState<HonorRequirementEvidence> createState() =>
      _HonorRequirementEvidenceState();
}

class _HonorRequirementEvidenceState
    extends ConsumerState<HonorRequirementEvidence> {
  bool _uploading = false;
  final Set<int> _deleting = {};

  String? get _userId => ref.read(authNotifierProvider).value?.id;

  void _showPicker() {
    if (!widget.enabled || _uploading) return;
    HapticFeedback.selectionClick();
    showSacSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SacSheetGrabber(),
            const SizedBox(height: 8),
            _PickerTile(
              icon: HugeIcons.strokeRoundedCamera01,
              color: ctx.sac.info,
              label: 'honors.requirements.pick_camera'.tr(),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            _PickerTile(
              icon: HugeIcons.strokeRoundedImage01,
              color: ctx.sac.success,
              label: 'honors.requirements.pick_gallery'.tr(),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            _PickerTile(
              icon: HugeIcons.strokeRoundedPdf01,
              color: ctx.sac.error,
              label: 'honors.requirements.pick_pdf'.tr(),
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

  Future<void> _pickImage(ImageSource source) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;
    await _upload(File(image.path));
  }

  Future<void> _pickPdf() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = picked?.path;
    if (path == null) return;
    await _upload(File(path));
  }

  Future<void> _upload(File file) async {
    final userId = _userId;
    if (userId == null) {
      if (!mounted) return;
      SacSnackBar.show(context, 'honors.evidence.no_session'.tr(),
          isError: true);
      return;
    }
    setState(() => _uploading = true);
    final success = await ref
        .read(
            requirementEvidenceActionsNotifierProvider(widget.honorId).notifier)
        .uploadRequirementEvidence(
          userId: userId,
          honorId: widget.honorId,
          requirementId: widget.requirementId,
          file: file,
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    SacSnackBar.show(
      context,
      success
          ? 'honors.requirements.requirement_evidence_success'.tr()
          : 'honors.requirements.requirement_evidence_error'.tr(),
      isSuccess: success,
      isError: !success,
    );
    if (success) widget.onChanged?.call();
  }

  Future<void> _delete(RequirementEvidence evidence) async {
    final userId = _userId;
    if (userId == null || !widget.enabled) return;
    final confirmed = await SacDialog.show(
      context,
      title: 'honors.evidence.delete_title'.tr(),
      content: 'honors.evidence.delete_content'.tr(),
      cancelLabel: 'honors.evidence.delete_cancel'.tr(),
      confirmLabel: 'honors.evidence.delete_confirm'.tr(),
      confirmIsDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting.add(evidence.id));
    final success = await ref
        .read(
            requirementEvidenceActionsNotifierProvider(widget.honorId).notifier)
        .deleteRequirementEvidence(
          userId: userId,
          honorId: widget.honorId,
          requirementId: widget.requirementId,
          evidenceId: evidence.id,
        );
    if (!mounted) return;
    setState(() => _deleting.remove(evidence.id));
    SacSnackBar.show(
      context,
      success
          ? 'honors.evidence.delete_success'.tr()
          : 'honors.evidence.delete_error'.tr(),
      isSuccess: success,
      isError: !success,
    );
    if (success) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final caption =
        widget.caption ?? 'honors.requirements.evidence_required_caption'.tr();

    return Column(
      key: const ValueKey('requirement-evidence'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HonorFieldCaption(caption),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final e in widget.evidences)
              _EvidenceThumb(
                key: ValueKey('requirement-evidence-${e.id}'),
                evidence: e,
                deleting: _deleting.contains(e.id),
                onDelete: widget.enabled ? () => _delete(e) : null,
              ),
            if (widget.enabled)
              _AddTile(
                color: widget.paintColor,
                uploading: _uploading,
                onTap: _showPicker,
              ),
          ],
        ),
        if (widget.enabled) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedInformationCircle,
                size: 14,
                color: c.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'honors.requirements.evidence_hint'.tr(),
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    color: c.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Small bold caption above a field ("Tu respuesta", "Evidencia").
class HonorFieldCaption extends StatelessWidget {
  const HonorFieldCaption(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: context.sac.textSecondary,
        ),
      ),
    );
  }
}

class _EvidenceThumb extends StatelessWidget {
  const _EvidenceThumb({
    super.key,
    required this.evidence,
    required this.deleting,
    required this.onDelete,
  });

  final RequirementEvidence evidence;
  final bool deleting;
  final VoidCallback? onDelete;

  bool get _isPdf =>
      evidence.mimeType == 'application/pdf' ||
      (evidence.filename ?? evidence.url).toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final radius = BorderRadius.circular(AppTheme.radiusSM);

    final tile = ClipRRect(
      borderRadius: radius,
      child: SizedBox.square(
        dimension: kHonorEvidenceTileSize,
        child: _isPdf || evidence.evidenceType == EvidenceType.link
            ? ColoredBox(
                color: c.surfaceVariant,
                child: Center(
                  child: HugeIcon(
                    icon: _isPdf
                        ? HugeIcons.strokeRoundedPdf01
                        : HugeIcons.strokeRoundedLink01,
                    size: 26,
                    color: c.textSecondary,
                  ),
                ),
              )
            : HonorSignedEvidenceImage(
                imageUrl: evidence.url,
                width: kHonorEvidenceTileSize,
                height: kHonorEvidenceTileSize,
                fit: BoxFit.cover,
                memCacheWidth: 216,
                memCacheHeight: 216,
                placeholder: (_, __) => ColoredBox(color: c.surfaceVariant),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: c.surfaceVariant,
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedImageDelete01,
                      size: 22,
                      color: c.textTertiary,
                    ),
                  ),
                ),
              ),
      ),
    );

    return SizedBox.square(
      dimension: kHonorEvidenceTileSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: tile),
          if (deleting)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.surface.withValues(alpha: 0.7),
                  borderRadius: radius,
                ),
                child: const Center(child: SacLoadingSmall()),
              ),
            )
          else if (onDelete != null)
            Positioned(
              top: -8,
              right: -8,
              child: Semantics(
                button: true,
                label: 'honors.evidence.delete_title'.tr(),
                excludeSemantics: true,
                child: GestureDetector(
                  key: const ValueKey('requirement-evidence-delete'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  // 32pt target around a 22pt badge.
                  child: SizedBox.square(
                    dimension: 32,
                    child: Center(
                      child: Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.surface,
                          border: Border.all(color: c.border),
                        ),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 12,
                          color: c.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.color,
    required this.uploading,
    required this.onTap,
  });

  final Color color;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isDark = Theme.brightnessOf(context) == Brightness.dark;
    final ink = isDark ? c.text : color;

    return Semantics(
      button: true,
      label: 'honors.requirements.evidence_add'.tr(),
      excludeSemantics: true,
      child: SacPressable(
        onTap: uploading ? null : onTap,
        child: Container(
          key: const ValueKey('requirement-evidence-add'),
          width: kHonorEvidenceTileSize,
          height: kHonorEvidenceTileSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            border: Border.all(color: ink.withValues(alpha: 0.45), width: 1.5),
          ),
          child: uploading
              ? const Center(child: SacLoadingSmall())
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedCameraAdd01,
                      size: 22,
                      color: ink,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'honors.requirements.evidence_add'.tr(),
                      style: TextStyle(
                        fontSize: SacFontSize.labelSmall,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final HugeIconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      listenOnly: true,
      child: ListTile(
        enableFeedback: false,
        leading: HugeIcon(icon: icon, color: color),
        title: Text(label),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}
