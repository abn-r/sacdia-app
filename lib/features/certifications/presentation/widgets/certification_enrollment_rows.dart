import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/animations/staggered_list_animation.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../domain/entities/user_certification.dart';
import '../utils/certification_status_view.dart';
import 'certification_row.dart';

/// «Certificaciones» group of Mis clases: one row per enrollment, the same row
/// as the club classes. Tapping opens the certification screen.
class CertificationEnrollmentRows extends StatelessWidget {
  const CertificationEnrollmentRows({
    super.key,
    required this.enrollments,
    this.index = 0,
  });

  final List<UserCertification> enrollments;

  /// Entrance position of the group.
  final int index;

  @override
  Widget build(BuildContext context) {
    final active = [
      for (final e in enrollments)
        if (e.isEnrolled) e,
    ];
    if (active.isEmpty) return const SizedBox.shrink();
    return SacEntrance(
      index: index,
      child: SacGroupedSection(
        key: const ValueKey('certification-enrollments-group'),
        label: 'certifications.mine.group'.tr(),
        dividerIndent: 62,
        children: [
          for (final e in active)
            CertificationRow(
              key: ValueKey('certification-enrollment-${e.enrollmentId}'),
              name: e.certificationName,
              meta: e.modulesTotal > 0
                  ? 'certifications.common.modules'.plural(e.modulesTotal)
                  : null,
              chipLabel: certificationEnrollmentLabel(e),
              chipTone: certificationChipTone(e.status),
              onTap: () => context.push(
                RouteNames.certificationDetailPath('${e.certificationId}'),
              ),
            ),
        ],
      ),
    );
  }
}
