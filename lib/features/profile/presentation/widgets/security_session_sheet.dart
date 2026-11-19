import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/utils/date_formatter.dart';
import 'package:sacdia_app/core/utils/relative_time.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

import '../../domain/entities/active_session.dart';
import '../utils/session_labels.dart';

/// Sheet of another open session: what is known about it and a destructive
/// "Cerrar esta sesión" row. Closes with `true` when the user closes it.
Future<bool?> showSessionSheet(BuildContext context, ActiveSession session) {
  return showSacSheet<bool>(
    context: context,
    builder: (_) => _SessionSheet(session: session),
  );
}

class _SessionSheet extends StatelessWidget {
  const _SessionSheet({required this.session});

  final ActiveSession session;

  @override
  Widget build(BuildContext context) {
    final location = session.location?.trim();
    final hasLocation = location != null && location.isNotEmpty;
    final place = sessionPlace(session);

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(title: sessionDisplayName(session)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SacSettingsGroup(
                children: [
                  SacSettingsValueTile(
                    icon: HugeIcons.strokeRoundedTime04,
                    label: 'settings.security.sheet_last_used'.tr(),
                    value: formatRelativeTime(session.lastActiveAt),
                  ),
                  const SacSettingsDivider(),
                  SacSettingsValueTile(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    label: 'settings.security.sheet_started'.tr(),
                    value: SacDateFormatter.dateTimeShort(session.createdAt),
                  ),
                  if (place != null) ...[
                    const SacSettingsDivider(),
                    SacSettingsValueTile(
                      icon: HugeIcons.strokeRoundedLocation01,
                      label: hasLocation
                          ? 'settings.security.sheet_location'.tr()
                          : 'settings.security.sheet_ip'.tr(),
                      value: place,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SacSettingsGroup(
                children: [
                  SacSettingsTile(
                    key: const ValueKey('session-sheet-close'),
                    icon: HugeIcons.strokeRoundedLogout01,
                    title: 'settings.security.close_this_session'.tr(),
                    subtitle: 'settings.security.close_this_session_hint'.tr(),
                    destructive: true,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
