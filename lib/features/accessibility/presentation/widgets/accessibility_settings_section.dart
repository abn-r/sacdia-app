import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';
import '../views/accessibility_view.dart';

/// Tile exportable — se inserta dentro de la sección APARIENCIA en
/// [SettingsView]. Navega a [AccessibilityView] vía Navigator.push (mismo
/// patrón que el resto de sub-pantallas de settings).
class AccessibilitySettingsSection extends StatelessWidget {
  const AccessibilitySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingTile(
      icon: HugeIcons.strokeRoundedUniversalAccess,
      title: 'settings.accessibility_tile'.tr(),
      iconColor: AppColors.primary,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AccessibilityView()),
        );
      },
    );
  }
}
