import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/support_chrome.dart';

class ContactView extends StatelessWidget {
  const ContactView({super.key});

  static const String routeName = '/settings/support/contact';
  static const String supportEmail = 'sacdia.app@gmail.com';

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: {
        'subject': 'support.email_subject'.tr(),
      },
    );
    final ok = await _tryLaunch(uri);
    if (!ok && context.mounted) {
      _showMessage(
        context,
        'support.channel_launch_failed'.tr(args: [supportEmail]),
      );
    }
  }

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (context.mounted) {
      _showMessage(context, 'support.contact_copied'.tr());
    }
  }

  Future<bool> _tryLaunch(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        return launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // Fall through to the copy hint.
    }
    return false;
  }

  void _showMessage(BuildContext context, String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    final padding = Responsive.horizontalPadding(context);

    return Scaffold(
      backgroundColor: c.background,
      appBar: supportAppBar(context, title: 'support.contact_title'.tr()),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          padding,
          8,
          padding,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          StaggeredListItem(
            index: 0,
            staggerDelay: SacMotion.stagger,
            duration: SacMotion.standard,
            slideOffset: 8,
            child: Text(
              'support.contact_intro'.tr(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                    height: 1.45,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          StaggeredListItem(
            index: 1,
            staggerDelay: SacMotion.stagger,
            duration: SacMotion.standard,
            slideOffset: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(color: c.border),
                boxShadow: [
                  BoxShadow(
                    color: c.shadow,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: scheme.secondary.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedMail01,
                              color: scheme.secondary,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'support.contact_email_title'.tr(),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      color: c.text,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                supportEmail,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: c.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SacButton.primary(
                      text: 'support.contact_email_title'.tr(),
                      icon: HugeIcons.strokeRoundedSent02,
                      onPressed: () => _openEmail(context),
                    ),
                    const SizedBox(height: 8),
                    SacButton.outline(
                      text: 'support.contact_copy'.tr(),
                      icon: HugeIcons.strokeRoundedCopy01,
                      onPressed: () => _copyEmail(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          StaggeredListItem(
            index: 2,
            staggerDelay: SacMotion.stagger,
            duration: SacMotion.standard,
            slideOffset: 8,
            child: Text(
              'support.contact_hours'.tr(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textTertiary,
                    height: 1.4,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
