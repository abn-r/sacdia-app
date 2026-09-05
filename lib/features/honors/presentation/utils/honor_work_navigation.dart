import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';

/// Resume path for an enrolled honor.
///
/// Catalog, profile, class "continuar", and post-enroll mode selection share
/// this destination so the member does not see a second hub after choosing
/// how to work the honor.
String honorWorkDestinationPath(
  UserHonor userHonor, {
  String? honorName,
}) {
  final honorId = userHonor.honorId.toString();
  final userHonorId = userHonor.id.toString();
  final name = (honorName ?? userHonor.honorName ?? '').trim();

  if (userHonor.isCompleted) {
    return RouteNames.honorDetailPath(honorId);
  }

  switch (userHonor.completionMode) {
    case HonorCompletionMode.inApp:
      return RouteNames.honorRequirementsPath(
        honorId,
        userHonorId,
        name,
      );
    case HonorCompletionMode.external:
      return RouteNames.honorEvidencePath(honorId, userHonorId);
    case HonorCompletionMode.undecided:
      return RouteNames.honorDetailPath(honorId);
  }
}

bool shouldResumeHonorWork(UserHonor userHonor) {
  if (userHonor.isCompleted) return false;
  return userHonor.completionMode == HonorCompletionMode.inApp ||
      userHonor.completionMode == HonorCompletionMode.external;
}

void openEnrolledHonorWork(
  BuildContext context,
  UserHonor userHonor, {
  String? honorName,
  Honor? extraHonor,
  bool replace = false,
}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;

  final path = honorWorkDestinationPath(
    userHonor,
    honorName: honorName,
  );
  if (replace) {
    router.pushReplacement(path, extra: extraHonor);
  } else {
    router.push(path, extra: extraHonor);
  }
}
