import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';

/// A single row in the hierarchical requirements tree.
///
/// Renders one [HonorRequirement] with:
///   - Depth-based indentation (24 dp per level)
///   - Circular check for completion (deferred to parent via [onToggle])
///   - Display label well ("1", "a", etc.)
///   - Expandable text (3-line clamp with "Ver más")
///   - Always-visible text response on leaf items (required to complete)
///   - Per-requirement evidence action when [requiresEvidence] is true
///   - Optional reference text accordion
///
/// Local expand/collapse state lives inside this widget.
/// Completion state is owned by the parent view and passed in as [completed].
class RequirementTreeItem extends StatefulWidget {
  final HonorRequirement requirement;

  /// Current completion status from parent state map.
  final bool completed;

  /// TextEditingController owned by the parent for this requirement's response.
  final TextEditingController? responseController;

  /// Depth level — 0 = top-level, 1 = sub-item. Drives left indentation.
  final int depth;

  /// Category color used for the check fill and evidence CTA.
  final Color categoryColor;

  /// Called when the user taps the checkbox.
  final VoidCallback onToggle;

  /// Number of active evidence files already attached to this requirement.
  final int evidenceCount;

  /// Whether this requirement is currently uploading evidence.
  final bool isUploadingEvidence;

  /// Called when the user wants to attach evidence to this requirement.
  final VoidCallback? onAddEvidence;

  /// When false, checks, responses and evidence cannot be changed
  /// (honor already submitted or approved).
  final bool enabled;

  const RequirementTreeItem({
    super.key,
    required this.requirement,
    required this.completed,
    required this.depth,
    required this.categoryColor,
    this.responseController,
    required this.onToggle,
    this.evidenceCount = 0,
    this.isUploadingEvidence = false,
    this.onAddEvidence,
    this.enabled = true,
  });

  @override
  State<RequirementTreeItem> createState() => _RequirementTreeItemState();
}

class _RequirementTreeItemState extends State<RequirementTreeItem> {
  bool _textExpanded = false;
  bool _referenceExpanded = false;
  bool _responseError = false;

  bool get _isLeaf =>
      !widget.requirement.hasSubItems || widget.requirement.children.isEmpty;

  @override
  void initState() {
    super.initState();
    widget.responseController?.addListener(_onResponseChanged);
  }

  @override
  void didUpdateWidget(covariant RequirementTreeItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.responseController != widget.responseController) {
      oldWidget.responseController?.removeListener(_onResponseChanged);
      widget.responseController?.addListener(_onResponseChanged);
    }
  }

  @override
  void dispose() {
    widget.responseController?.removeListener(_onResponseChanged);
    super.dispose();
  }

  void _onResponseChanged() {
    if (!mounted || !widget.enabled) return;
    if (_responseError && _responseText.isNotEmpty) {
      setState(() => _responseError = false);
    }
    if (widget.completed && _isLeaf && _responseText.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.enabled) return;
        if (widget.completed && _isLeaf && _responseText.isEmpty) {
          widget.onToggle();
        }
      });
    }
  }

  String get _responseText =>
      widget.responseController?.text.trim() ?? '';

  void _onCheck() {
    if (!widget.enabled) return;
    if (_isLeaf && !widget.completed && _responseText.isEmpty) {
      HapticFeedback.lightImpact();
      setState(() => _responseError = true);
      return;
    }
    widget.onToggle();
  }

  double get _indentLeft => widget.depth * 24.0;

  bool get _needsExpandToggle => widget.requirement.text.length > 120;

  Duration _motion(BuildContext context) =>
      SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;

  @override
  Widget build(BuildContext context) {
    final req = widget.requirement;
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final expandDuration = _motion(context);
    final label = (req.displayLabel != null && req.displayLabel!.isNotEmpty)
        ? req.displayLabel!
        : '${req.requirementNumber}';

    return Padding(
      padding: EdgeInsets.only(left: _indentLeft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CircleCheck(
                  key: const ValueKey('requirement-check'),
                  checked: widget.completed,
                  color: widget.categoryColor,
                  enabled: widget.enabled,
                  onToggle: _onCheck,
                ),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            setState(() => _textExpanded = !_textExpanded),
                        child: AnimatedSize(
                          duration: expandDuration,
                          curve: SacMotion.easeOut,
                          alignment: Alignment.topLeft,
                          child: AnimatedDefaultTextStyle(
                            duration: expandDuration,
                            curve: SacMotion.easeOut,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: widget.completed ? c.textTertiary : c.text,
                            ),
                            child: Text(
                              req.text,
                              maxLines: _textExpanded ? null : 3,
                              overflow: _textExpanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      if (_needsExpandToggle)
                        GestureDetector(
                          onTap: () =>
                              setState(() => _textExpanded = !_textExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              _textExpanded
                                  ? 'honors.requirements.see_less'.tr()
                                  : 'honors.requirements.see_more'.tr(),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: c.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                if (req.requiresEvidence)
                  Tooltip(
                    message: 'honors.requirements.requires_demo'.tr(),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCamera01,
                        size: 16,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (req.requiresEvidence)
            Padding(
              padding: const EdgeInsets.only(left: 38, bottom: 10),
              child: _RequirementEvidenceAction(
                evidenceCount: widget.evidenceCount,
                isUploading: widget.isUploadingEvidence,
                categoryColor: widget.categoryColor,
                onAddEvidence: widget.enabled ? widget.onAddEvidence : null,
              ),
            ),
          if (_isLeaf)
            Padding(
              padding: const EdgeInsets.only(left: 38, bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SacTextField(
                    controller: widget.responseController,
                    hint: 'honors.requirements.response_hint'.tr(),
                    maxLines: 3,
                    maxLength: 800,
                    enabled: widget.enabled,
                  ),
                  if (_responseError)
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 6),
                      child: Text(
                        'honors.requirements.response_required'.tr(),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          if (req.referenceText != null && req.referenceText!.isNotEmpty)
            _ReferenceAccordion(
              referenceText: req.referenceText!,
              expanded: _referenceExpanded,
              onToggle: () =>
                  setState(() => _referenceExpanded = !_referenceExpanded),
              indentLeft: 38,
              reduceMotion: reduce,
            ),
        ],
      ),
    );
  }
}

class _CircleCheck extends StatefulWidget {
  final bool checked;
  final Color color;
  final bool enabled;
  final VoidCallback onToggle;

  const _CircleCheck({
    super.key,
    required this.checked,
    required this.color,
    required this.onToggle,
    this.enabled = true,
  });

  @override
  State<_CircleCheck> createState() => _CircleCheckState();
}

class _CircleCheckState extends State<_CircleCheck> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    final duration = reduce ? Duration.zero : SacMotion.press;
    final c = context.sac;

    return Semantics(
      button: true,
      checked: widget.checked,
      enabled: widget.enabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) {
                HapticFeedback.selectionClick();
                _setPressed(true);
              }
            : null,
        onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        onTap: widget.enabled ? widget.onToggle : null,
        child: Padding(
          padding: const EdgeInsets.only(top: 2, right: 2, bottom: 8),
          child: AnimatedScale(
            scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
            duration: duration,
            curve: SacMotion.easeOut,
            child: SizedBox(
              width: 24,
              height: 24,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.checked ? widget.color : Colors.transparent,
                  border: Border.all(
                    color: widget.checked ? widget.color : c.border,
                    width: 1.5,
                  ),
                ),
                child: widget.checked
                    ? const Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedTick02,
                          size: 13,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
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

class _ReferenceAccordion extends StatelessWidget {
  final String referenceText;
  final bool expanded;
  final VoidCallback onToggle;
  final double indentLeft;
  final bool reduceMotion;

  const _ReferenceAccordion({
    required this.referenceText,
    required this.expanded,
    required this.onToggle,
    required this.indentLeft,
    required this.reduceMotion,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final duration = reduceMotion ? Duration.zero : SacMotion.standard;

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
                  color: c.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  'honors.requirements.reference_label'.tr(),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(width: 2),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: duration,
                  curve: SacMotion.easeOut,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowDown01,
                    size: 16,
                    color: c.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: duration,
              curve: SacMotion.easeOut,
              alignment: Alignment.topCenter,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: c.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: c.border),
                        ),
                        child: Text(
                          referenceText,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}
