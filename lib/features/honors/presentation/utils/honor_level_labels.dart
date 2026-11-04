import 'package:easy_localization/easy_localization.dart';

/// Label of an honor's approval level (General, Avanzado, Master).
String honorApprovalLabel(int level) {
  switch (level) {
    case 1:
      return 'honors.detail.approval_general'.tr();
    case 2:
      return 'honors.detail.approval_advanced'.tr();
    case 3:
      return 'honors.detail.approval_master'.tr();
    default:
      return 'honors.detail.approval_level'.tr(namedArgs: {'level': '$level'});
  }
}

/// Label of an honor's skill level (Básico, Intermedio, Avanzado); empty when
/// the honor has none.
String honorSkillLevelLabel(int? level) {
  switch (level) {
    case 1:
      return 'honors.detail.skill_basic'.tr();
    case 2:
      return 'honors.detail.skill_intermediate'.tr();
    case 3:
      return 'honors.detail.skill_advanced'.tr();
    default:
      return level != null
          ? 'honors.detail.skill_level_n'.tr(namedArgs: {'level': '$level'})
          : '';
  }
}
