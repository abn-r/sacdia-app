import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';

import '../providers/camporees_providers.dart';
import 'camporee_detail_view.dart';

/// Vista de lista de camporees.
///
/// Prioriza patrones móviles nativos: AppBar estándar, tarjetas legibles,
/// targets táctiles amplios y colores semánticos del design system.
class CamporeesListView extends ConsumerWidget {
  const CamporeesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camporeesAsync = ref.watch(camporeesProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: SacBackButton(
          color: c.text,
          tooltip: 'common.back'.tr(),
          onPressed: () => context.go(RouteNames.homeDashboard),
        ),
        title: Text(
          'camporees.list.title'.tr(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: c.border),
        ),
      ),
      body: SafeArea(
        top: false,
        child: camporeesAsync.when(
          data: (camporees) {
            if (camporees.isEmpty) {
              return _EmptyCamporeesState(
                onRetry: () => ref.invalidate(camporeesProvider),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(camporeesProvider),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 28),
                itemCount: camporees.length,
                itemBuilder: (context, index) {
                  final camporee = camporees[index];
                  return StaggeredListItem(
                    index: index,
                    initialDelay: const Duration(milliseconds: 40),
                    staggerDelay: const Duration(milliseconds: 45),
                    child: _CamporeeCard(
                      camporee: camporee,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CamporeeDetailView(
                              camporeeId: camporee.camporeeId,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const _CamporeesSkeleton(),
          error: (error, stack) => _ErrorState(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () => ref.invalidate(camporeesProvider),
          ),
        ),
      ),
    );
  }
}

class _CamporeeCard extends StatelessWidget {
  final Camporee camporee;
  final VoidCallback onTap;

  const _CamporeeCard({
    required this.camporee,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final currencyFormatter = NumberFormat.currency(
      locale: context.locale.toString(),
      symbol: '\$',
      decimalDigits: 0,
      customPattern: '¤#,##0',
    );
    final dateRange = _smartDateRange(
      camporee.startDate.toLocal(),
      camporee.endDate.toLocal(),
      context.locale.toString(),
    );

    return Semantics(
      button: true,
      label: camporee.name,
      hint: 'camporees.detail.description'.tr(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _Pressable(
          onTap: onTap,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardBanner(dateRange: dateRange),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camporee.name,
                        style: TextStyle(
                          color: c.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (camporee.localFieldName != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          camporee.localFieldName!,
                          style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      _MetaRow(
                        icon: HugeIcons.strokeRoundedLocation01,
                        text: camporee.place,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: _ClubTypeBadges(camporee: camporee)),
                          if (camporee.registrationCost != null) ...[
                            const SizedBox(width: 10),
                            Text(
                              _formatCost(
                                camporee.registrationCost!,
                                currencyFormatter,
                              ),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: camporee.registrationCost == 0
                                    ? c.success
                                    : c.text,
                                height: 1,
                                letterSpacing: -0.2,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Rango compacto: colapsa mes/año repetidos.
  /// "20 – 23 may 2026" · "28 may – 2 jun 2026" · "30 dic 2026 – 2 ene 2027".
  String _smartDateRange(DateTime start, DateTime end, String locale) {
    final full = DateFormat('d MMM yyyy', locale);
    if (start.year == end.year && start.month == end.month) {
      return '${start.day} – ${full.format(end)}';
    }
    if (start.year == end.year) {
      return '${DateFormat('d MMM', locale).format(start)} – ${full.format(end)}';
    }
    return '${full.format(start)} – ${full.format(end)}';
  }

  String _formatCost(double cost, NumberFormat formatter) {
    if (cost == 0) return 'camporees.common.free'.tr();
    return formatter.format(cost);
  }
}

/// Banner superior con gradiente coral y fogata como marca de agua.
/// La fecha es la protagonista: es el dato que decide si el evento importa.
class _CardBanner extends StatelessWidget {
  final String dateRange;

  const _CardBanner({required this.dateRange});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.coral500, AppColors.coral700],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Fogata watermark, sangrada al borde derecho
          Positioned(
            right: -10,
            top: -14,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedCampfire,
              size: 100,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'camporees.list.title'.tr().toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.75),
                    letterSpacing: 1.4,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  dateRange,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                    height: 1,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Press feedback: scale en touch-down (respuesta instantánea, Apple §1).
class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _Pressable({required this.child, this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value || widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = SacMotion.reduceMotionOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: (!reduce && _pressed) ? 0.98 : 1,
        duration: SacMotion.press,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final HugeIconData icon;
  final String text;

  const _MetaRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: HugeIcon(icon: icon, size: 15, color: c.textTertiary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              color: c.textSecondary,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final HugeIconData icon;
  final Color color;
  final double size;

  const _IconTile({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Center(
        child: HugeIcon(icon: icon, size: size * 0.50, color: color),
      ),
    );
  }
}

class _ClubTypeBadges extends StatelessWidget {
  final Camporee camporee;

  const _ClubTypeBadges({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (camporee.includesAdventurers)
        _Badge(
          label: 'camporees.common.adventurers'.tr(),
          color: context.sac.warning,
        ),
      if (camporee.includesPathfinders)
        _Badge(
          label: 'camporees.common.pathfinders'.tr(),
          color: AppColors.primary,
        ),
      if (camporee.includesMasterGuides)
        _Badge(
          label: 'camporees.common.master_guides'.tr(),
          color: context.sac.success,
        ),
    ];

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
      ),
    );
  }
}

class _EmptyCamporeesState extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyCamporeesState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconTile(
              icon: HugeIcons.strokeRoundedCampfire,
              color: AppColors.primary,
              size: 88,
            ),
            const SizedBox(height: 18),
            Text(
              'camporees.list.empty'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'camporees.list.subtitle'.tr(),
              style: TextStyle(
                color: c.textSecondary,
                height: 1.45,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),
            SacButton.outline(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconTile(
              icon: HugeIcons.strokeRoundedAlert02,
              color: c.error,
              size: 72,
            ),
            const SizedBox(height: 16),
            Text(
              'camporees.list.error_loading'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: c.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SacButton.primary(
              text: 'common.retry'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _CamporeesSkeleton extends StatelessWidget {
  const _CamporeesSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 28),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        height: 152,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.borderLight),
        ),
      ),
    );
  }
}
