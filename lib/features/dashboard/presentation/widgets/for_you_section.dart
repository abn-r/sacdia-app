import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/authorization/access_subject.dart';
import 'package:sacdia_app/core/authorization/screen_catalog.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/virtual_card/presentation/views/virtual_card_view.dart';

/// Pantalla del catálogo que gobierna «Recursos» (concedida a todo rol de club).
const String _resourcesScreenId = 'resources-list';

/// «Para ti» del inicio en modo miembro, apilado por importancia:
///
/// 1. Credencial: lo que el miembro abre en eventos.
/// 2. Especialidades: cuántas lleva en curso y validadas, con barra de avance.
/// 3. Recursos: fila sencilla, solo si el catálogo concede `resources-list`.
///
/// Las tres tarjetas comparten estilo; cada atajo tiene su propio color en el
/// ícono, como el acceso rápido del director.
class ForYouSection extends ConsumerWidget {
  const ForYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final showResources = canViewScreen(
      subjectFromUser(user),
      _resourcesScreenId,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('dashboard.for_you.title'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.sac.text,
              ),
        ),
        const SizedBox(height: 12),
        _ShortcutRow(
          title: tr('dashboard.for_you.credential'),
          subtitle: tr('dashboard.for_you.credential_subtitle'),
          icon: HugeIcons.strokeRoundedQrCode,
          iconColor: context.sac.onInfoContainer,
          wellColor: context.sac.infoContainer,
          onTap: () => Navigator.push(
            context,
            SacSharedAxisRoute(builder: (_) => const VirtualCardView()),
          ),
        ),
        const SizedBox(height: 8),
        _HonorsCard(onTap: () => context.push(RouteNames.homeHonors)),
        if (showResources) ...[
          const SizedBox(height: 8),
          _ShortcutRow(
            title: tr('dashboard.for_you.resources'),
            subtitle: tr('dashboard.for_you.resources_subtitle'),
            icon: HugeIcons.strokeRoundedFiles01,
            iconColor: AppColors.primary,
            wellColor: AppColors.primary.withValues(alpha: 0.12),
            onTap: () => context.push(RouteNames.homeResources),
          ),
        ],
      ],
    );
  }
}

/// Especialidades con el resumen local (`userHonorStatsLocalProvider`, sin
/// llamada extra). Mientras carga o si falla, solo se ve el título.
class _HonorsCard extends ConsumerWidget {
  const _HonorsCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final stats = ref.watch(userHonorStatsLocalProvider).value;
    final total = (stats?['total'] as int?) ?? 0;
    final validated = (stats?['validated'] as int?) ?? 0;
    final inProgress = (stats?['in_progress'] as int?) ?? 0;

    final String? subtitle;
    if (stats == null) {
      subtitle = null;
    } else if (total == 0) {
      subtitle = tr('dashboard.for_you.honors_empty');
    } else {
      subtitle = tr(
        'dashboard.for_you.honors_summary',
        namedArgs: {
          'in_progress': '$inProgress',
          'validated': '$validated',
        },
      );
    }

    return _ShortcutRow(
      title: tr('dashboard.for_you.honors'),
      subtitle: subtitle,
      icon: HugeIcons.strokeRoundedMedal01,
      iconColor: c.onSuccessContainer,
      wellColor: c.successContainer,
      onTap: onTap,
      footer: total > 0
          ? Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
                child: LinearProgressIndicator(
                  value: validated / total,
                  minHeight: 4,
                  backgroundColor: c.successContainer,
                  color: c.success,
                ),
              ),
            )
          : null,
    );
  }
}

/// Fila a lo ancho: pozo de color, título y subtítulo, flecha.
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.wellColor,
    required this.onTap,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final HugeIconData icon;
  final Color iconColor;
  final Color wellColor;
  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title. $subtitle',
      onTap: onTap,
      excludeSemantics: true,
      child: SacCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _IconWell(
                    icon: icon, iconColor: iconColor, wellColor: wellColor),
                const SizedBox(width: 12),
                Expanded(
                  child: _TitleBlock(
                    title: title,
                    subtitle: subtitle,
                    titleColor: c.text,
                    subtitleColor: c.textSecondary,
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),
            if (footer != null) footer!,
          ],
        ),
      ),
    );
  }
}

class _IconWell extends StatelessWidget {
  const _IconWell({
    required this.icon,
    required this.iconColor,
    required this.wellColor,
  });

  final HugeIconData icon;
  final Color iconColor;
  final Color wellColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: wellColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: HugeIcon(icon: icon, size: 20, color: iconColor),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({
    required this.title,
    required this.titleColor,
    required this.subtitleColor,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Color titleColor;
  final Color subtitleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: SacFontSize.titleMedium,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: SacFontSize.bodyMedium,
              color: subtitleColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
