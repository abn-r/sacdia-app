import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/widgets/status_progress/status_progress.dart';
import '../utils/counselor_rows.dart';

/// One class of the counselors screen: who is its counselor and
/// sub-counselor. A class with no counselor gets the alert icon and the line
/// in the error color.
class CounselorClassRow extends StatelessWidget {
  const CounselorClassRow({
    super.key,
    required this.row,
    required this.onTap,
    this.isEditable = true,
  });

  final ClassCounselorRow row;
  final VoidCallback onTap;

  /// Without permission to assign the row only informs: no chevron, no tap.
  final bool isEditable;

  String _detail() {
    final primary = row.primary;
    if (primary == null) return 'classes.grouped.assign.no_counselor'.tr();
    final counselor = counselorPersonName(primary.user, primary.userId);
    final assistant = row.assistant;
    final second = assistant == null
        ? 'classes.grouped.assign.no_assistant'.tr()
        : counselorPersonName(assistant.user, assistant.userId);
    return '$counselor · $second';
  }

  @override
  Widget build(BuildContext context) {
    final hasCounselor = row.hasCounselor;
    final style = SacStatusStyle.of(
      context,
      hasCounselor ? SacStatusKind.pending : SacStatusKind.rejected,
      label: hasCounselor
          ? 'classes.grouped.role_counselor'.tr()
          : 'classes.grouped.no_counselor'.tr(),
      icon: hasCounselor
          ? HugeIcons.strokeRoundedUserMultiple
          : HugeIcons.strokeRoundedAlertCircle,
    );

    return SacStatusRow(
      key: ValueKey('counselor-row-${row.classId}'),
      style: style,
      title: row.name,
      detail: _detail(),
      detailIsError: !hasCounselor,
      onTap: isEditable ? onTap : () {},
      trailing: isEditable ? null : const SizedBox.shrink(),
    );
  }
}
