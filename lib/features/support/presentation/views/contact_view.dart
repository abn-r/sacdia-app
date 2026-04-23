import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../profile/presentation/widgets/setting_tile.dart';

/// Contacto directo con el equipo de SACDIA.
///
/// Canales disponibles:
/// - Email: sacdia.app@gmail.com (mailto con asunto prellenado).
/// - WhatsApp: wa.me link (el backend de WhatsApp Business se encarga del ruteo).
class ContactView extends StatelessWidget {
  const ContactView({super.key});

  static const String routeName = '/settings/support/contact';

  // Canales centralizados aquí para cambiarlos rápido sin tocar i18n.
  static const String _supportEmail = 'sacdia.app@gmail.com';
  static const String _whatsappNumber = '525555555555'; // TODO: actualizar al número oficial
  static const String _whatsappDisplay = '+52 55 5555 5555';

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'support.email_subject'.tr(),
      },
    );
    final ok = await _tryLaunch(uri);
    if (!ok && context.mounted) {
      _showFallback(context, _supportEmail);
    }
  }

  Future<void> _openWhatsapp(BuildContext context) async {
    final text = Uri.encodeComponent('support.whatsapp_default_message'.tr());
    final uri = Uri.parse('https://wa.me/$_whatsappNumber?text=$text');
    final ok = await _tryLaunch(uri);
    if (!ok && context.mounted) {
      _showFallback(context, _whatsappDisplay);
    }
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // ignore — caemos al fallback
    }
    return false;
  }

  void _showFallback(BuildContext context, String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('support.channel_launch_failed'.tr(args: [value])),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('support.contact_title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                'support.contact_intro'.tr(),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            _Card(children: [
              SettingTile(
                icon: HugeIcons.strokeRoundedMail01,
                title: 'support.contact_email_title'.tr(),
                subtitle: _supportEmail,
                iconColor: AppColors.primary,
                onTap: () => _openEmail(context),
              ),
              const _Divider(),
              SettingTile(
                icon: HugeIcons.strokeRoundedWhatsapp,
                title: 'support.contact_whatsapp_title'.tr(),
                subtitle: _whatsappDisplay,
                iconColor: Colors.green,
                onTap: () => _openWhatsapp(context),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'support.contact_hours'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
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
