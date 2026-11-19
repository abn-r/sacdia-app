import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

/// Warning shown when the phone denied notifications for the app: what it
/// means for the user and a button to the phone settings.
class NotificationPermissionCard extends StatelessWidget {
  const NotificationPermissionCard({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.warningContainer,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.warning,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedNotificationOff01,
                        size: 22,
                        color: c.onWarning,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'settings.notifications.denied_title'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.titleLarge,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: c.onWarningContainer,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'settings.notifications.denied_body'.tr(),
                        style: TextStyle(
                          fontSize: SacFontSize.bodyMedium,
                          height: 1.4,
                          color: c.onWarningContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SacButton(
              variant: SacButtonVariant.outline,
              size: SacButtonSize.small,
              text: 'settings.notifications.open_phone_settings'.tr(),
              icon: HugeIcons.strokeRoundedLinkSquare02,
              onPressed: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
