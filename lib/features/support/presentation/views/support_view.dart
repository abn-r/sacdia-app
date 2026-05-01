import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';

/// Hub principal de Soporte/Ayuda. Tres accesos:
/// - FAQ (pantalla de preguntas frecuentes bundleadas)
/// - Contactar (email + WhatsApp)
/// - Reportar un problema (formulario → backend)
class SupportView extends StatelessWidget {
  const SupportView({super.key});

  static const String routeName = '/settings/support';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('support.title'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SectionHeader(label: 'support.section_get_help'.tr()),
            _TilesCard(children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedHelpCircle,
                title: 'support.faq_tile'.tr(),
                subtitle: 'support.faq_tile_subtitle'.tr(),
                iconColor: AppColors.primary,
                onTap: () => context.push('/settings/support/faq'),
              ),
              const _Divider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedCustomerSupport,
                title: 'support.contact_tile'.tr(),
                subtitle: 'support.contact_tile_subtitle'.tr(),
                iconColor: Colors.green,
                onTap: () => context.push('/settings/support/contact'),
              ),
              const _Divider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedBug01,
                title: 'support.report_tile'.tr(),
                subtitle: 'support.report_tile_subtitle'.tr(),
                iconColor: Colors.orange,
                onTap: () => context.push('/settings/support/report'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.black54,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _TilesCard extends StatelessWidget {
  const _TilesCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 60),
        child: Divider(height: 0, thickness: 0.5),
      );
}
