import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../dashboard/presentation/widgets/class_logo_box.dart';
import '../../domain/entities/class_with_progress.dart';

/// Status line of a class: vencida or in progress. Null when invested: the
/// investiture row of the screen already says it, and saying it twice reads
/// as two different facts.
String? classStatusLabel(ClassWithProgress classData) {
  if (classData.isInvested) return null;
  if (classData.isExpired) return 'classes.catalog.status.expired'.tr();
  return 'classes.catalog.status.in_progress'.tr();
}

/// Class logo, name and its status.
class ClassDetailHeader extends StatelessWidget {
  const ClassDetailHeader({super.key, required this.classData});

  final ClassWithProgress classData;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final status = classStatusLabel(classData);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Semantics(
        container: true,
        header: true,
        excludeSemantics: true,
        label: [classData.name, if (status != null) status].join('. '),
        child: Row(
          children: [
            ClassLogoBox(
              className: classData.name,
              imageUrl: classData.imageUrl,
              size: 56,
              padding: 8,
              radius: AppTheme.radiusSM,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    classData.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: SacFontSize.headlineMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: c.text,
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
