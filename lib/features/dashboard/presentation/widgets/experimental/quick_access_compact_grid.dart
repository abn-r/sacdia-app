import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../quick_access_items.dart';

/// Experimental layout kept for future use (option C/D of the 2026-11 home
/// redesign). Not routed; see quick_access_layouts_preview_view_test.dart.
///
/// Opción C: el launcher del inicio en tres columnas de tiles compactos
/// (alto ~104, well de 44 con radio 12 al 12 % del color, etiqueta de dos
/// líneas). Usa los mismos accesos y permisos que [QuickAccessGrid]
/// ([visibleQuickAccessItemsProvider]).
class QuickAccessCompactGrid extends ConsumerWidget {
  const QuickAccessCompactGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleQuickAccessItemsProvider);
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: tr('dashboard.quick_access.title')),
        const SizedBox(height: 12),
        _CompactTilesGrid(items: items),
      ],
    );
  }
}

/// Experimental layout kept for future use (option C/D of the 2026-11 home
/// redesign). Not routed; see quick_access_layouts_preview_view_test.dart.
///
/// Opción D: los mismos tiles compactos agrupados bajo encabezados «Club»,
/// «Formación» y «Administración». Los grupos vacíos no se pintan y un acceso
/// que ningún grupo reclame (ruta nueva) cae en «Club» para no perderse.
class QuickAccessGroupedGrid extends ConsumerWidget {
  const QuickAccessGroupedGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleQuickAccessItemsProvider);
    final groups = groupQuickAccessItems(items);
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < groups.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _SectionTitle(title: tr(groups[i].titleKey)),
          const SizedBox(height: 12),
          _CompactTilesGrid(items: groups[i].items),
        ],
      ],
    );
  }
}

/// Grupo de la opción D.
class QuickAccessGroup {
  const QuickAccessGroup({required this.titleKey, required this.items});

  final String titleKey;
  final List<QuickAccessItem> items;
}

const _clubGroupRoutes = {
  RouteNames.homeMembers,
  RouteNames.homeUnits,
  RouteNames.homeClub,
};

const _trainingGroupRoutes = {
  RouteNames.homeGroupedClass,
  RouteNames.homeEvidences,
  RouteNames.sectionInvestiture,
  RouteNames.investitureAuthorize,
  RouteNames.homeClubRankings,
  RouteNames.homeCamporees,
  RouteNames.camporeeJudgeAssignments,
  RouteNames.homeResources,
};

const _adminGroupRoutes = {
  RouteNames.homeFinances,
  RouteNames.homeInsurance,
  RouteNames.homeInventory,
  RouteNames.homeMaterials,
  RouteNames.homeReports,
};

/// Reparte [items] en «Club», «Formación» y «Administración» (en ese orden),
/// conservando el orden relativo de cada grupo y omitiendo los vacíos.
List<QuickAccessGroup> groupQuickAccessItems(List<QuickAccessItem> items) {
  final club = <QuickAccessItem>[];
  final training = <QuickAccessItem>[];
  final admin = <QuickAccessItem>[];

  for (final item in items) {
    if (_trainingGroupRoutes.contains(item.route)) {
      training.add(item);
    } else if (_adminGroupRoutes.contains(item.route)) {
      admin.add(item);
    } else {
      // Incluye _clubGroupRoutes y cualquier ruta aún sin grupo asignado.
      assert(
        _clubGroupRoutes.contains(item.route),
        'Quick access route ${item.route} has no group; falling back to Club',
      );
      club.add(item);
    }
  }

  return [
    if (club.isNotEmpty)
      QuickAccessGroup(
        titleKey: 'dashboard.quick_access.group_club',
        items: club,
      ),
    if (training.isNotEmpty)
      QuickAccessGroup(
        titleKey: 'dashboard.quick_access.group_training',
        items: training,
      ),
    if (admin.isNotEmpty)
      QuickAccessGroup(
        titleKey: 'dashboard.quick_access.group_admin',
        items: admin,
      ),
  ];
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        title,
        style: TextStyle(
          fontSize: SacFontSize.bodyMedium,
          fontWeight: FontWeight.w600,
          color: context.sac.textSecondary,
        ),
      ),
    );
  }
}

class _CompactTilesGrid extends StatelessWidget {
  const _CompactTilesGrid({required this.items});

  final List<QuickAccessItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      // shrinkWrap OK: permission-gated list from a small compile-time catalog,
      // hosted inside a scroll view.
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 104,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) => _CompactTile(item: items[index]),
    );
  }
}

class _CompactTile extends StatelessWidget {
  const _CompactTile({required this.item});

  final QuickAccessItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.color ?? SacAccent.of(context).color;
    final label = tr(item.labelKey);
    void open() => context.push(item.route);

    return Semantics(
      button: true,
      label: label,
      onTap: open,
      excludeSemantics: true,
      child: SacCard(
        onTap: open,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: HugeIcon(icon: item.icon, size: 22, color: color),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.labelSmall,
                fontWeight: FontWeight.w600,
                color: context.sac.text,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
