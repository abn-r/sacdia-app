import 'package:easy_localization/easy_localization.dart';
import 'package:sacdia_app/core/widgets/sac_badge.dart';

/// Label of an activity type: the backend name when present, else the
/// translated default for the known ids. Shared by the list card and the
/// detail screen so both show the same chip.
String activityTypeLabel(int type, [String? typeName]) {
  final name = typeName?.trim();
  if (name != null && name.isNotEmpty) return name;
  switch (type) {
    case 1:
      return 'activities.detail.type_regular'.tr();
    case 2:
      return 'activities.detail.type_special'.tr();
    case 3:
      return 'activities.detail.type_camporee'.tr();
    default:
      return 'activities.detail.type_activity'.tr();
  }
}

/// Badge variant of an activity type (same mapping in list and detail).
SacBadgeVariant activityTypeBadgeVariant(int type) {
  switch (type) {
    case 1:
      return SacBadgeVariant.primary;
    case 2:
      return SacBadgeVariant.accent;
    case 3:
      return SacBadgeVariant.secondary;
    default:
      return SacBadgeVariant.neutral;
  }
}
