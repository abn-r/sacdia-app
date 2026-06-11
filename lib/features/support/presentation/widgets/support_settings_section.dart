import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';
import '../views/support_view.dart';

/// Sección "Ayuda y Soporte" para incrustar en `SettingsView`.
///
/// El orquestador tiene que:
/// 1. Importar este widget en `settings_view.dart`.
/// 2. Colocarlo dentro del scroll (idealmente después de la sección de
///    notificaciones, antes del bloque "Acerca de").
///
/// No toca ningún estado global — solo navega al hub de Soporte.
class SupportSettingsSection extends StatelessWidget {
  const SupportSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'support.section_title'.tr().toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              color: context.sac.textTertiary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: context.sac.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.sac.border, width: 1),
          ),
          child: SettingTile(
            icon: HugeIcons.strokeRoundedHelpCircle,
            title: 'support.settings_entry_title'.tr(),
            subtitle: 'support.settings_entry_subtitle'.tr(),
            iconColor: AppColors.primary,
            onTap: () => context.push(SupportView.routeName),
          ),
        ),
      ],
    );
  }
}
