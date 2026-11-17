import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_member_avatar.dart';
import '../../domain/entities/class_progress_summary.dart';

/// The counselor and the sub-counselor of a class, one card each. A role
/// with nobody assigned shows a dashed "Unassigned" card.
class GroupedPeopleCards extends StatelessWidget {
  const GroupedPeopleCards({
    super.key,
    required this.counselor,
    required this.assistant,
  });

  final ClassResponsible? counselor;
  final ClassResponsible? assistant;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PersonCard(
          key: const ValueKey('grouped-counselor-card'),
          role: 'classes.grouped.role_counselor'.tr(),
          person: counselor,
        ),
        const SizedBox(height: 8),
        _PersonCard(
          key: const ValueKey('grouped-assistant-card'),
          role: 'classes.grouped.role_assistant'.tr(),
          person: assistant,
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({super.key, required this.role, required this.person});

  final String role;
  final ClassResponsible? person;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final person = this.person;
    final name = person == null
        ? 'classes.grouped.unassigned'.tr()
        : (person.name.isEmpty ? person.userId : person.name);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          person == null
              ? Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.border),
                  ),
                  child: ExcludeSemantics(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      size: 16,
                      color: c.textTertiary,
                    ),
                  ),
                )
              : SacMemberAvatar(name: name, size: 32),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: TextStyle(
                    fontSize: SacFontSize.labelSmall,
                    color: c.textSecondary,
                  ),
                ),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: SacFontSize.bodyMedium,
                    fontWeight: FontWeight.w600,
                    color: person == null ? c.textTertiary : c.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: '$role: $name',
      excludeSemantics: true,
      child: person == null
          ? CustomPaint(
              foregroundPainter: _DashedBorderPainter(
                color: c.border,
                radius: AppTheme.radiusMD,
              ),
              child: content,
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: content,
            ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double _dash = 5;
  static const double _gap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dash),
          paint,
        );
        distance += _dash + _gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
