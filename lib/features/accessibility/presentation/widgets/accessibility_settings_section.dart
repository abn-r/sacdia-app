import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_settings.dart';
import 'package:hugeicons/hugeicons.dart';

import '../views/accessibility_view.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';

/// Tile exportable — se inserta dentro de la sección APARIENCIA en
/// [SettingsView]. Navega a [AccessibilityView] vía Navigator.push (mismo
/// patrón que el resto de sub-pantallas de settings).
class AccessibilitySettingsSection extends StatelessWidget {
  const AccessibilitySettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return SacSettingsTile(
      icon: HugeIcons.strokeRoundedUniversalAccess,
      title: 'settings.accessibility_tile'.tr(),
      onTap: () {
        Navigator.push(
          context,
          SacSharedAxisRoute(builder: (_) => const AccessibilityView()),
        );
      },
    );
  }
}
