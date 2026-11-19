import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_state_panel.dart';
import 'package:sacdia_app/core/widgets/status_progress/sac_status_style.dart';

import '../../domain/entities/data_export.dart';

/// Where the data copy stands, as one state (never a path of steps).
enum MyDataPhase { none, preparing, ready, failed, expired }

/// The phase to show for [exports]: a copy in progress wins; otherwise the
/// newest one decides; no copies is [MyDataPhase.none].
MyDataPhase myDataPhaseOf(List<DataExport> exports) {
  if (exports.isEmpty) return MyDataPhase.none;
  if (exports.any((e) => e.isInProgress)) return MyDataPhase.preparing;
  final latest = latestDataExport(exports)!;
  switch (latest.status) {
    case DataExportStatus.ready:
      return MyDataPhase.ready;
    case DataExportStatus.failed:
      return MyDataPhase.failed;
    case DataExportStatus.expired:
      return MyDataPhase.expired;
    case DataExportStatus.pending:
    case DataExportStatus.processing:
      return MyDataPhase.preparing;
  }
}

/// Newest export by request date, or null.
DataExport? latestDataExport(List<DataExport> exports) {
  DataExport? latest;
  for (final e in exports) {
    if (latest == null || e.createdAt.isAfter(latest.createdAt)) latest = e;
  }
  return latest;
}

/// [SacStatePanel] for the current phase. The panel cross-fades by itself when
/// the title changes (M6), so a new phase fades in over the old one.
class MyDataStatePanel extends StatelessWidget {
  const MyDataStatePanel({
    super.key,
    required this.phase,
    required this.exports,
    required this.now,
  });

  final MyDataPhase phase;
  final List<DataExport> exports;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final latest = latestDataExport(exports);

    final SacStatusStyle style;
    final String title;
    final String message;
    switch (phase) {
      case MyDataPhase.none:
        style = SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: '',
          icon: HugeIcons.strokeRoundedDownload02,
        );
        title = 'settings.my_data.none_title'.tr();
        message = 'settings.my_data.none_message'.tr();
      case MyDataPhase.preparing:
        style = SacStatusStyle.of(
          context,
          SacStatusKind.review,
          label: '',
          icon: HugeIcons.strokeRoundedLoading03,
        );
        title = 'settings.my_data.preparing_title'.tr();
        message = 'settings.my_data.preparing_message'.tr();
      case MyDataPhase.ready:
        style = SacStatusStyle.of(
          context,
          SacStatusKind.validated,
          label: '',
        );
        title = 'settings.my_data.ready_title'.tr();
        final expires = latest?.expiresAt;
        message = expires != null && expires.isAfter(now)
            ? 'settings.my_data.ready_message'.tr(
                namedArgs: {
                  'time': formatDataExportWait(expires.difference(now)),
                },
              )
            : 'settings.my_data.ready_message_no_expiry'.tr();
      case MyDataPhase.failed:
        style = SacStatusStyle.of(
          context,
          SacStatusKind.rejected,
          label: '',
        );
        title = 'settings.my_data.failed_title'.tr();
        message = 'settings.my_data.failed_message'.tr();
      case MyDataPhase.expired:
        style = SacStatusStyle.of(
          context,
          SacStatusKind.pending,
          label: '',
          icon: HugeIcons.strokeRoundedTime04,
        );
        title = 'settings.my_data.expired_title'.tr();
        message = 'settings.my_data.expired_message'.tr();
    }

    return SacStatePanel(
      key: const ValueKey('my-data-panel'),
      style: style,
      title: title,
      message: message,
    );
  }
}
