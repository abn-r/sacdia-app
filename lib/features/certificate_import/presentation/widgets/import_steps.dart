import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/sac_state_swap.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

/// Upload → Read → Review indicator shown while a proof is being processed.
///
/// [current] is the zero-based active step: earlier steps show a check, later
/// ones stay muted. Reduced Motion keeps the 160 ms fade and drops the scale.
class ImportSteps extends StatelessWidget {
  const ImportSteps({super.key, required this.current});

  final int current;

  static const _labels = [
    'certificate_import.steps.upload',
    'certificate_import.steps.read',
    'certificate_import.steps.review',
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;
    final reduce = SacMotion.reduceMotionOf(context);
    final duration = reduce ? SacMotion.reducedFade : SacMotion.switcher;

    Widget dot(int index) {
      final done = index < current;
      final active = index == current;
      return AnimatedContainer(
        duration: duration,
        curve: SacMotion.easeOut,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done
              ? c.success
              : active
                  ? accent
                  : Colors.transparent,
          border:
              Border.all(color: done || active ? Colors.transparent : c.border),
        ),
        alignment: Alignment.center,
        child: SacStateSwap(
          duration: duration,
          child: done
              ? HugeIcon(
                  key: const ValueKey('done'),
                  icon: HugeIcons.strokeRoundedTick02,
                  size: 14,
                  color: Colors.white,
                )
              : Text(
                  '${index + 1}',
                  key: ValueKey('number-$index-$active'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: active ? Colors.white : c.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: AnimatedContainer(
                duration: duration,
                curve: SacMotion.easeOut,
                height: 2,
                margin: const EdgeInsets.only(bottom: 18),
                color: i <= current ? c.success : c.border,
              ),
            ),
          _Step(
            index: i,
            label: _labels[i].tr(),
            status: i < current
                ? 'certificate_import.steps.done'.tr()
                : i == current
                    ? 'certificate_import.steps.active'.tr()
                    : 'certificate_import.steps.pending'.tr(),
            dot: dot(i),
            emphasized: i == current,
          ),
        ],
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.index,
    required this.label,
    required this.status,
    required this.dot,
    required this.emphasized,
  });

  final int index;
  final String label;
  final String status;
  final Widget dot;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      container: true,
      label: 'certificate_import.steps.semantics'.tr(namedArgs: {
        'n': '${index + 1}',
        'label': label,
        'status': status,
      }),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot,
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: emphasized ? c.text : c.textTertiary,
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
