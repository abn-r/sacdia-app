import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';

/// A single row in the hierarchical requirements tree.
///
/// Renders one [HonorRequirement] with:
///   - Depth-based indentation (24 dp per level)
///   - Checkbox for completion toggle (deferred to parent via [onToggle])
///   - Display label badge ("1", "a", etc.)
///   - Expandable text (3-line clamp with "Ver más")
///   - Optional text-response text field (shown when requirement has or gains a response)
///   - Per-requirement evidence action when [requiresEvidence] is true
///   - Optional reference text accordion
///
/// Local expand/collapse and showNotes state live inside this widget.
/// Completion state is owned by the parent view and passed in as [completed].
class RequirementTreeItem extends StatefulWidget {
  final HonorRequirement requirement;

  /// Current completion status from parent state map.
  final bool completed;

  /// Current text response from parent controller/state.
  final String? textResponse;

  /// TextEditingController owned by the parent for this requirement's response.
  final TextEditingController? responseController;

  /// Depth level — 0 = top-level, 1 = sub-item. Drives left indentation.
  final int depth;

  /// Category color used for accent elements (checkbox, labels, etc.).
  final Color categoryColor;

  /// Called when the user taps the checkbox.
  final VoidCallback onToggle;

  /// Number of active evidence files already attached to this requirement.
  final int evidenceCount;

  /// Whether this requirement is currently uploading evidence.
  final bool isUploadingEvidence;

  /// Called when the user wants to attach evidence to this requirement.
  final VoidCallback? onAddEvidence;

  const RequirementTreeItem({
    super.key,
    required this.requirement,
    required this.completed,
    required this.depth,
    required this.categoryColor,
    this.textResponse,
    this.responseController,
    required this.onToggle,
    this.evidenceCount = 0,
    this.isUploadingEvidence = false,
    this.onAddEvidence,
  });

  @override
  State<RequirementTreeItem> createState() => _RequirementTreeItemState();
}

class _RequirementTreeItemState extends State<RequirementTreeItem> {
  bool _textExpanded = false;
  bool _showResponse = false;
  bool _referenceExpanded = false;

  @override
  void initState() {
    super.initState();
    // Auto-show response field if there is an existing response.
    _showResponse =
        widget.textResponse != null && widget.textResponse!.isNotEmpty;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  double get _indentLeft => widget.depth * 24.0;

  bool get _needsExpandToggle => widget.requirement.text.length > 120;

  void _handleToggle() {
    HapticFeedback.selectionClick();
    widget.onToggle();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final req = widget.requirement;

    return Padding(
      padding: EdgeInsets.only(left: _indentLeft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main row ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: widget.completed,
                    onChanged: (_) => _handleToggle(),
                    activeColor: widget.categoryColor,
                    checkColor: Colors.white,
                    side: BorderSide(
                      color: widget.completed
                          ? widget.categoryColor
                          : context.sac.border,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 8),

                // Display label badge
                if (req.displayLabel != null && req.displayLabel!.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.lightText.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      req.displayLabel!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.sac.textSecondary,
                      ),
                    ),
                  )
                else
                  // Fallback: show requirement number for top-level items
                  Container(
                    margin: const EdgeInsets.only(top: 1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.lightText.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${req.requirementNumber}.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.sac.textSecondary,
                      ),
                    ),
                  ),

                const SizedBox(width: 8),

                // Text block
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _textExpanded = !_textExpanded),
                        child: Text(
                          req.text,
                          maxLines: _textExpanded ? null : 3,
                          overflow: _textExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.55,
                            color: widget.completed
                                ? context.sac.textTertiary
                                : context.sac.text,
                            decoration: widget.completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: context.sac.textTertiary,
                          ),
                        ),
                      ),
                      if (_needsExpandToggle)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _textExpanded = !_textExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _textExpanded
                                  ? 'honors.requirements.see_less'.tr()
                                  : 'honors.requirements.see_more'.tr(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: widget.categoryColor,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // ── Trailing action icons ─────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Response toggle
                    GestureDetector(
                      onTap: () =>
                          setState(() => _showResponse = !_showResponse),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: HugeIcon(
                          icon: _showResponse
                              ? HugeIcons.strokeRoundedNote
                              : HugeIcons.strokeRoundedNote,
                          size: 18,
                          color: _showResponse
                              ? widget.categoryColor
                              : context.sac.textTertiary,
                        ),
                      ),
                    ),

                    // requiresEvidence indicator
                    if (req.requiresEvidence)
                      Tooltip(
                        message: 'honors.requirements.requires_demo'.tr(),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCamera01,
                            size: 16,
                            color: context.sac.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // ── Requirement evidence action ──────────────────────────────────
          if (req.requiresEvidence)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 10),
              child: _RequirementEvidenceAction(
                evidenceCount: widget.evidenceCount,
                isUploading: widget.isUploadingEvidence,
                categoryColor: widget.categoryColor,
                onAddEvidence: widget.onAddEvidence,
              ),
            ),

          // ── Text response field ───────────────────────────────────────────
          if (_showResponse)
            Padding(
              padding: const EdgeInsets.only(
                left: 40,
                bottom: 10,
              ),
              child: SacTextField(
                controller: widget.responseController,
                hint: 'honors.requirements.response_hint'.tr(),
                maxLines: 4,
                maxLength: 800,
              ),
            ),

          // ── Reference text accordion ──────────────────────────────────────
          if (req.referenceText != null && req.referenceText!.isNotEmpty)
            _ReferenceAccordion(
              referenceText: req.referenceText!,
              expanded: _referenceExpanded,
              categoryColor: widget.categoryColor,
              onToggle: () =>
                  setState(() => _referenceExpanded = !_referenceExpanded),
              indentLeft: 40,
            ),
        ],
      ),
    );
  }
}

class _RequirementEvidenceAction extends StatelessWidget {
  final int evidenceCount;
  final bool isUploading;
  final Color categoryColor;
  final VoidCallback? onAddEvidence;

  const _RequirementEvidenceAction({
    required this.evidenceCount,
    required this.isUploading,
    required this.categoryColor,
    required this.onAddEvidence,
  });

  @override
  Widget build(BuildContext context) {
    final hasEvidence = evidenceCount > 0;
    final label = isUploading
        ? 'honors.requirements.requirement_evidence_uploading'.tr()
        : hasEvidence
            ? 'honors.requirements.requirement_evidence_count'
                .tr(namedArgs: {'count': '$evidenceCount'})
            : 'honors.requirements.requirement_evidence_button'.tr();

    return SacButton(
      text: label,
      icon: hasEvidence
          ? HugeIcons.strokeRoundedCheckmarkCircle02
          : HugeIcons.strokeRoundedUpload01,
      onPressed: isUploading ? null : onAddEvidence,
      isLoading: isUploading,
      variant: SacButtonVariant.outline,
      fullWidth: true,
      size: SacButtonSize.small,
      textColor: hasEvidence ? AppColors.success : categoryColor,
      borderColor: (hasEvidence ? AppColors.success : categoryColor)
          .withValues(alpha: 0.45),
      fontSize: 12,
      iconSize: 18,
      borderRadius: 10,
    );
  }
}

// ── Reference text accordion ──────────────────────────────────────────────────

class _ReferenceAccordion extends StatelessWidget {
  final String referenceText;
  final bool expanded;
  final Color categoryColor;
  final VoidCallback onToggle;
  final double indentLeft;

  const _ReferenceAccordion({
    required this.referenceText,
    required this.expanded,
    required this.categoryColor,
    required this.onToggle,
    required this.indentLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indentLeft, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedBookOpen01,
                  size: 14,
                  color: categoryColor.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
                Text(
                  'honors.requirements.reference_label'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: 2),
                HugeIcon(
                  icon: expanded
                      ? HugeIcons.strokeRoundedArrowUp01
                      : HugeIcons.strokeRoundedArrowDown01,
                  size: 16,
                  color: categoryColor,
                ),
              ],
            ),
          ),
          if (expanded)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: categoryColor.withValues(alpha: 0.2),
                ),
              ),
              child: Text(
                referenceText,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: context.sac.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
