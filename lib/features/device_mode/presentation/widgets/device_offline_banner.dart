import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

/// Franja «Sin conexión»: lo que se ve es lo último guardado y es de solo
/// lectura.
class DeviceOfflineBanner extends StatelessWidget {
  const DeviceOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      key: const ValueKey('device_offline_banner'),
      width: double.infinity,
      color: c.warningContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedWifiOff01,
            size: 16,
            color: c.onWarningContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'device.offline'.tr(),
              style: TextStyle(
                  color: c.onWarningContainer,
                  fontSize: SacFontSize.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
