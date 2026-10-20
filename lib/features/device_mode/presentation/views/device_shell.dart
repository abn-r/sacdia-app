import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_nav_icon.dart';
import '../../../../core/widgets/sac_shell_nav.dart';
import '../providers/device_connectivity_provider.dart';
import '../widgets/device_offline_banner.dart';

/// Cáscara del teléfono vinculado de un menor de 13 (FP3-52): cuatro pestañas
/// — Inicio, Clases, Agenda y Avisos — y nada más. Sin perfil, sin ajustes de
/// cuenta, sin Mi familia, sin chat ni mensajes.
class DeviceShell extends ConsumerWidget {
  const DeviceShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = <({HugeIconData icon, String labelKey})>[
    (icon: HugeIcons.strokeRoundedHome01, labelKey: 'device.tabs.home'),
    (icon: HugeIcons.strokeRoundedCourse, labelKey: 'device.tabs.classes'),
    (icon: HugeIcons.strokeRoundedCalendar01, labelKey: 'device.tabs.agenda'),
    (
      icon: HugeIcons.strokeRoundedNotification01,
      labelKey: 'device.tabs.notices',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final online = isDeviceOnline(ref.watch(deviceOnlineProvider));
    final selected = navigationShell.currentIndex;

    return Scaffold(
      body: Column(
        children: [
          if (!online)
            SafeArea(bottom: false, child: const DeviceOfflineBanner()),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: SacShellNavBar(
        selectedIndex: selected,
        onSelected: (index) =>
            navigationShell.goBranch(index, initialLocation: index == selected),
        destinations: [
          for (final tab in _tabs)
            SacShellDestination(
              icon: SacNavIcon(icon: tab.icon),
              selectedIcon: SacNavIcon(icon: tab.icon, selected: true),
              label: tab.labelKey.tr(),
            ),
        ],
      ),
    );
  }
}
