import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Text(
            'support.section_title'.tr().toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black54,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
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
