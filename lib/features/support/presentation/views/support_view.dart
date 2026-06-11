import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_back_button.dart';

class SupportView extends StatelessWidget {
  const SupportView({super.key});

  static const String routeName = '/settings/support';

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: sacAutoBackButton(context),
        title: Text('support.title'.tr()),
        backgroundColor: c.surfaceVariant,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          const _SupportHero(),
          const SizedBox(height: 18),
          Text(
            'support.section_get_help'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          _SupportRouteCard(
            icon: HugeIcons.strokeRoundedCompass01,
            iconColor: AppColors.primary,
            title: 'support.faq_tile'.tr(),
            subtitle: 'support.faq_tile_subtitle'.tr(),
            accentLabel: 'support.route_faq_label'.tr(),
            onTap: () => context.push('/settings/support/faq'),
          ),
          const SizedBox(height: 12),
          _SupportRouteCard(
            icon: HugeIcons.strokeRoundedMail01,
            iconColor: AppColors.secondary,
            title: 'support.contact_tile'.tr(),
            subtitle: 'support.contact_tile_subtitle'.tr(),
            accentLabel: 'support.route_contact_label'.tr(),
            onTap: () => context.push('/settings/support/contact'),
          ),
          const SizedBox(height: 12),
          _SupportRouteCard(
            icon: HugeIcons.strokeRoundedBug01,
            iconColor: AppColors.accentDark,
            title: 'support.report_tile'.tr(),
            subtitle: 'support.report_tile_subtitle'.tr(),
            accentLabel: 'support.route_report_label'.tr(),
            onTap: () => context.push('/settings/support/report'),
          ),
        ],
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: c.surface,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: c.shadow.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -24,
            top: -28,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCampfire,
              color: AppColors.primary.withValues(alpha: 0.08),
              size: 120,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HugeIcon(
                      icon: HugeIcons.strokeRoundedRoute01,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _supportCopy(context, 'support.hub_badge'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _supportCopy(context, 'support.hub_title'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                _supportCopy(context, 'support.hub_intro'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: c.textSecondary,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _HeroPill(
                    icon: HugeIcons.strokeRoundedHelpCircle,
                    label: 'support.faq_tile'.tr(),
                  ),
                  const SizedBox(width: 8),
                  _HeroPill(
                    icon: HugeIcons.strokeRoundedSent02,
                    label: 'support.report_tile'.tr(),
                  ),
                ],
              ),
            ],
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _supportCopy(BuildContext context, String key) {
  if (context.locale.languageCode != 'es') return key.tr();

  switch (key) {
    case 'support.hub_badge':
      return 'Ruta de ayuda';
    case 'support.hub_title':
      return 'Encuentra la ruta correcta para tu duda';
    case 'support.hub_intro':
      return 'Encuentra respuestas rápidas, escríbenos por correo o envía un reporte con contexto técnico.';
  }

  return key.tr();
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.icon, required this.label});

  final HugeIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, color: AppColors.secondaryDark, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.secondaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportRouteCard extends StatefulWidget {
  const _SupportRouteCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.accentLabel,
    required this.onTap,
  });

  final HugeIconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String accentLabel;
  final VoidCallback onTap;

  @override
  State<_SupportRouteCard> createState() => _SupportRouteCardState();
}

class _SupportRouteCardState extends State<_SupportRouteCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      scale: _pressed ? 0.98 : 1,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border),
            boxShadow: [
              BoxShadow(
                color: c.shadow.withValues(alpha: 0.03),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: widget.icon,
                    color: widget.iconColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.accentLabel,
                      style: TextStyle(
                        color: widget.iconColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textSecondary,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                color: c.textTertiary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
