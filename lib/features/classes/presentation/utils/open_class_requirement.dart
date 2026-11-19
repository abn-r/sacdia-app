import 'package:flutter/material.dart';

import '../../../../core/animations/page_transitions.dart';
import '../../domain/entities/class_requirement.dart';
import '../../domain/entities/class_with_progress.dart';
import '../views/requirement_detail_view.dart';

/// Opens the requirement screen of [requirement]. The screen re-reads the
/// requirement from the class progress, so a list watching that provider is
/// up to date when it comes back.
void openClassRequirement(
  BuildContext context, {
  required ClassRequirement requirement,
  required ClassWithProgress classData,
  required int classId,
  int? enrollmentId,
  String? targetUserId,
}) {
  Navigator.push(
    context,
    SacSharedAxisRoute(
      builder: (_) => RequirementDetailView(
        requirement: requirement,
        classId: classId,
        enrollmentId: enrollmentId ?? classData.enrollmentId,
        targetUserId: targetUserId,
        isClassExpired: classData.isExpired,
        isClassInvested: classData.isInvested,
      ),
    ),
  );
}
