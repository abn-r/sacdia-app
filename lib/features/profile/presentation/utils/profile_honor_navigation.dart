import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';

/// Resolves the best destination when opening an enrolled honor from Profile.
///
/// Profile is the user's "my work" surface, not the catalog. Once an honor has
/// a selected completion mode, tapping it should resume that workflow directly.
String profileHonorDestinationPath(UserHonor userHonor) {
  final honorId = userHonor.honorId.toString();
  final userHonorId = userHonor.id.toString();

  if (userHonor.isCompleted) {
    return RouteNames.honorDetailPath(honorId);
  }

  switch (userHonor.completionMode) {
    case HonorCompletionMode.inApp:
      return RouteNames.honorRequirementsPath(
        honorId,
        userHonorId,
        userHonor.honorName ?? '',
      );
    case HonorCompletionMode.external:
      return RouteNames.honorEvidencePath(honorId, userHonorId);
    case HonorCompletionMode.undecided:
      return RouteNames.honorDetailPath(honorId);
  }
}
