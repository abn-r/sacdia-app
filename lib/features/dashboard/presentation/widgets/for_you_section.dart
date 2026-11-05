import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/authorization/access_subject.dart';
import 'package:sacdia_app/core/authorization/screen_catalog.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/virtual_card/presentation/views/virtual_card_view.dart';

/// Pantalla del catálogo que gobierna «Recursos» (concedida a todo rol de club).
const String _resourcesScreenId = 'resources-list';

/// «Para ti» del inicio en modo miembro: atajos personales en una fila de
/// cuatro columnas iguales (Especialidades, Logros, Credencial y, si el
/// catálogo lo concede, Recursos; sin Recursos son tres columnas).
class ForYouSection extends ConsumerWidget {
  const ForYouSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final showResources = canViewScreen(
      subjectFromUser(user),
      _resourcesScreenId,
    );

    final tiles = <_ForYouTile>[
      _ForYouTile(
        labelKey: 'dashboard.for_you.honors',
        icon: HugeIcons.strokeRoundedMedal01,
        onTap: () => context.push(RouteNames.homeHonors),
      ),
      _ForYouTile(
        labelKey: 'dashboard.for_you.achievements',
        icon: HugeIcons.strokeRoundedTrophy,
        onTap: () => context.push(RouteNames.homeAchievements),
      ),
      _ForYouTile(
        labelKey: 'dashboard.for_you.credential',
        icon: HugeIcons.strokeRoundedQrCode,
        onTap: () => Navigator.push(
          context,
          SacSharedAxisRoute(builder: (_) => const VirtualCardView()),
        ),
      ),
      if (showResources)
        _ForYouTile(
          labelKey: 'dashboard.for_you.resources',
          icon: HugeIcons.strokeRoundedFiles01,
          onTap: () => context.push(RouteNames.homeResources),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('dashboard.for_you.title'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.sac.text,
              ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ],
        ),
      ],
    );
  }
}

class _ForYouTile extends StatelessWidget {
  const _ForYouTile({
    required this.labelKey,
    required this.icon,
    required this.onTap,
  });

  final String labelKey;
  final HugeIconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = SacAccent.of(context).color;
    final label = tr(labelKey);

    return Semantics(
      button: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: SacCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: HugeIcon(icon: icon, size: 22, color: accent),
            ),
            const SizedBox(height: 8),
            // Single long words ("Especialidades") shrink instead of being
            // cut or broken mid-word in the 4-column row.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  fontWeight: FontWeight.w600,
                  color: context.sac.text,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
