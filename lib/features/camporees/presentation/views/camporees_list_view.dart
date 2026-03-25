import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee.dart';

import '../providers/camporees_providers.dart';
import 'camporee_detail_view.dart';

/// Vista de lista de camporees.
///
/// Muestra tarjetas de camporees activos. Cada tarjeta incluye nombre, fechas,
/// lugar, costo y badges de tipos de club. Navega al detalle al tocar.
class CamporeesListView extends ConsumerWidget {
  const CamporeesListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final camporeesAsync = ref.watch(camporeesProvider);
    final hPad = Responsive.horizontalPadding(context);
    final c = context.sac;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: camporeesAsync.when(
          data: (camporees) {
            if (camporees.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedAward01,
                      size: 56,
                      color: c.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No hay camporees disponibles',
                      style: TextStyle(
                        fontSize: 16,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(camporeesProvider);
              },
              child: ListView.builder(
                padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 24),
                itemCount: camporees.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          HugeIcon(
                            icon: HugeIcons.strokeRoundedAward01,
                            size: 24,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Camporees',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    );
                  }

                  final camporee = camporees[index - 1];
                  return StaggeredListItem(
                    index: index - 1,
                    initialDelay: const Duration(milliseconds: 80),
                    staggerDelay: const Duration(milliseconds: 65),
                    child: _CamporeeCard(
                      camporee: camporee,
                      onTap: () {
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
          loading: () => const Center(child: SacLoading()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedAlert02,
                    size: 56,
                    color: AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error al cargar camporees',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString().replaceFirst('Exception: ', ''),
                    style: TextStyle(fontSize: 14, color: c.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SacButton.primary(
                    text: 'Reintentar',
                    icon: HugeIcons.strokeRoundedRefresh,
                    onPressed: () => ref.invalidate(camporeesProvider),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Camporee Card ──────────────────────────────────────────────────────────────

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
    final dateFormat = DateFormat('d MMM yyyy', 'es');
    final startFormatted = dateFormat.format(camporee.startDate.toLocal());
    final endFormatted = dateFormat.format(camporee.endDate.toLocal());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
          boxShadow: [
            BoxShadow(
              color: c.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ícono + nombre
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAward01,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        camporee.name,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                      ),
                      if (camporee.localFieldName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          camporee.localFieldName!,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedArrowRight01,
                  size: 18,
                  color: c.textTertiary,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Fechas + lugar
            _InfoRow(
              icon: HugeIcons.strokeRoundedCalendar01,
              text: '$startFormatted – $endFormatted',
            ),
            const SizedBox(height: 6),
            _InfoRow(
              icon: HugeIcons.strokeRoundedLocation01,
              text: camporee.place,
            ),
            if (camporee.registrationCost != null) ...[
              const SizedBox(height: 6),
              _InfoRow(
                icon: HugeIcons.strokeRoundedMoney01,
                text: _formatCost(camporee.registrationCost!),
              ),
            ],

            const SizedBox(height: 12),

            // Club type badges
            _ClubTypeBadges(camporee: camporee),
          ],
        ),
      ),
    );
  }

  String _formatCost(double cost) {
    if (cost == 0) return 'Gratuito';
    final formatted = NumberFormat.currency(
      locale: 'es',
      symbol: '\$',
      decimalDigits: 0,
    ).format(cost);
    return formatted;
  }
}

// ── Info Row ───────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final dynamic icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HugeIcon(icon: icon, size: 14, color: context.sac.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: context.sac.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Club Type Badges ───────────────────────────────────────────────────────────

class _ClubTypeBadges extends StatelessWidget {
  final Camporee camporee;

  const _ClubTypeBadges({required this.camporee});

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[];

    if (camporee.includesAdventurers) {
      badges.add(_Badge(label: 'Aventureros', color: AppColors.warning));
    }
    if (camporee.includesPathfinders) {
      badges.add(_Badge(label: 'Conquistadores', color: AppColors.primary));
    }
    if (camporee.includesMasterGuides) {
      badges.add(_Badge(label: 'G. Mayores', color: AppColors.secondary));
    }

    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 4,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
