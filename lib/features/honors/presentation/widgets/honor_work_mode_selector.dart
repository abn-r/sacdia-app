import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';

/// Selector explícito del camino de trabajo de una especialidad inscrita.
///
/// Se muestra únicamente cuando el backend indica `UNDECIDED`, o al cambiar
/// de modo. La app no debe mezclar checklist dentro de la app con formato
/// externo en la misma CTA.
class HonorWorkModeSelector extends StatelessWidget {
  final Color categoryColor;
  final bool isLoading;
  final bool showIntro;
  final HonorCompletionMode? selectedMode;
  final ValueChanged<HonorCompletionMode> onSelected;

  const HonorWorkModeSelector({
    super.key,
    required this.categoryColor,
    required this.onSelected,
    this.isLoading = false,
    this.showIntro = true,
    this.selectedMode,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showIntro) ...[
          Text(
            'honors.work_mode.title'.tr(),
            style: TextStyle(
              color: c.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'honors.work_mode.subtitle'.tr(),
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
        ],
        _ModeOptionCard(
          title: 'honors.work_mode.in_app_title'.tr(),
          description: 'honors.work_mode.in_app_description'.tr(),
          icon: HugeIcons.strokeRoundedTaskEdit01,
          categoryColor: categoryColor,
          selected: selectedMode == HonorCompletionMode.inApp,
          enabled: !isLoading,
          onTap: () => onSelected(HonorCompletionMode.inApp),
        ),
        const SizedBox(height: 10),
        _ModeOptionCard(
          title: 'honors.work_mode.external_title'.tr(),
          description: 'honors.work_mode.external_description'.tr(),
          icon: HugeIcons.strokeRoundedPdf01,
          categoryColor: categoryColor,
          selected: selectedMode == HonorCompletionMode.external,
          enabled: !isLoading,
          onTap: () => onSelected(HonorCompletionMode.external),
        ),
        if (isLoading && showIntro) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'honors.work_mode.saving'.tr(),
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ModeOptionCard extends StatefulWidget {
  final String title;
  final String description;
  final HugeIconData icon;
  final Color categoryColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.categoryColor,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_ModeOptionCard> createState() => _ModeOptionCardState();
}

class _ModeOptionCardState extends State<_ModeOptionCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final reduce = SacMotion.reduceMotionOf(context);
    final selected = widget.selected;
    final duration = reduce ? Duration.zero : SacMotion.press;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: selected,
      label: widget.title,
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
        onTap: widget.enabled ? widget.onTap : null,
        child: AnimatedScale(
          scale: (!reduce && _pressed) ? SacMotion.pressScale : 1,
          duration: duration,
          curve: SacMotion.easeOut,
          child: AnimatedContainer(
            duration: reduce ? Duration.zero : SacMotion.standard,
            curve: SacMotion.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? widget.categoryColor : c.border,
                width: selected ? 1.5 : 1,
              ),
            ),
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
                    icon: widget.icon,
                    color: selected ? widget.categoryColor : c.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _ModeRadio(
                    selected: selected,
                    color: widget.categoryColor,
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

class _ModeRadio extends StatelessWidget {
  final bool selected;
  final Color color;

  const _ModeRadio({
    required this.selected,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? color : Colors.transparent,
          border: Border.all(
            color: selected ? color : context.sac.border,
            width: 1.5,
          ),
        ),
        child: selected
            ? const Center(
                child: SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
