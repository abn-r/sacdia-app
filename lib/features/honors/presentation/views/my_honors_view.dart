import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/animations/animated_counter.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/usecases/get_honors.dart';
import '../providers/honors_providers.dart';
import '../widgets/honor_progress_card.dart';

/// Vista de "Mis Honores" - Estilo "Scout Vibrante"
///
/// Tabs: "En progreso" (indigo) / "Completados" (amber badge).
/// Stats header con 3 mini cards con AnimatedCounter.
/// Lista con staggered slide-up entrance.
class MyHonorsView extends ConsumerWidget {
  const MyHonorsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userHonorsAsync = ref.watch(userHonorsProvider);
    final statsAsync = ref.watch(userHonorStatsProvider);
    final honorsAsync = ref.watch(honorsProvider(const GetHonorsParams()));
    final hPad = Responsive.horizontalPadding(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.sac.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              StaggeredListItem(
                index: 0,
                initialDelay: const Duration(milliseconds: 60),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 0),
                  child: Row(
                    children: [
                      HugeIcon(
                          icon: HugeIcons.strokeRoundedMedal01,
                          size: 24,
                          color: AppColors.accent),
                      const SizedBox(width: 10),
                      Text(
                        'Mis Especialidades',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stats row with AnimatedCounter values
              StaggeredListItem(
                index: 1,
                initialDelay: const Duration(milliseconds: 60),
                child: statsAsync.when(
                  data: (stats) => Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Row(
                      children: [
                        _StatMini(
                          value: stats['total'] ?? 0,
                          label: 'Total',
                          color: AppColors.primary,
                          bgColor: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 10),
                        _StatMini(
                          value: stats['in_progress'] ?? 0,
                          label: 'En progreso',
                          color: AppColors.primary,
                          bgColor: AppColors.primaryLight,
                        ),
                        const SizedBox(width: 10),
                        _StatMini(
                          value: stats['completed'] ?? 0,
                          label: 'Completadas',
                          color: AppColors.accent,
                          bgColor: AppColors.accentLight,
                        ),
                      ],
                    ),
                  ),
                  loading: () => const SizedBox(height: 60),
                  error: (_, __) => const SizedBox(),
                ),
              ),
              const SizedBox(height: 16),

              // Tab bar
              StaggeredListItem(
                index: 2,
                initialDelay: const Duration(milliseconds: 60),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: hPad),
                  decoration: BoxDecoration(
                    color: context.sac.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: context.sac.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x10000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerHeight: 0,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: context.sac.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'En progreso'),
                      Tab(text: 'Completados'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Tab content
              Expanded(
                child: userHonorsAsync.when(
                  data: (userHonors) {
                    if (userHonors.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            HugeIcon(
                                icon: HugeIcons.strokeRoundedAward01,
                                size: 56,
                                color: context.sac.textTertiary),
                            const SizedBox(height: 12),
                            Text(
                              'No tienes especialidades',
                              style: TextStyle(
                                fontSize: 16,
                                color: context.sac.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Inscríbete en el catálogo',
                              style: TextStyle(
                                fontSize: 14,
                                color: context.sac.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return honorsAsync.when(
                      data: (honors) {
                        final inProgress = userHonors
                            .where((uh) =>
                                uh.status.toLowerCase() != 'completed')
                            .toList();
                        final completed = userHonors
                            .where((uh) =>
                                uh.status.toLowerCase() == 'completed')
                            .toList();

                        return TabBarView(
                          children: [
                            _buildHonorsList(
                              context,
                              ref,
                              inProgress,
                              honors,
                              emptyMessage: 'No tienes honores en progreso',
                              hPad: hPad,
                            ),
                            _buildHonorsList(
                              context,
                              ref,
                              completed,
                              honors,
                              emptyMessage: 'Aún no has completado honores',
                              hPad: hPad,
                            ),
                          ],
                        );
                      },
                      loading: () => const Center(child: SacLoading()),
                      error: (error, _) =>
                          Center(child: Text('Error: $error')),
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
                              color: AppColors.error),
                          const SizedBox(height: 16),
                          Text('Error al cargar especialidades',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 24),
                          SacButton.primary(
                            text: 'Reintentar',
                            icon: HugeIcons.strokeRoundedRefresh,
                            onPressed: () {
                              ref.invalidate(userHonorsProvider);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHonorsList(
    BuildContext context,
    WidgetRef ref,
    List userHonors,
    List honors, {
    required String emptyMessage,
    required double hPad,
  }) {
    if (userHonors.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            fontSize: 14,
            color: context.sac.textSecondary,
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        ref.invalidate(userHonorsProvider);
        ref.invalidate(userHonorStatsProvider);
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 24),
        itemCount: userHonors.length,
        itemBuilder: (context, index) {
          final userHonor = userHonors[index];
          final honor = honors.firstWhere(
            (h) => h.id == userHonor.honorId,
            orElse: () => throw Exception('Honor no encontrado'),
          );

          return StaggeredListItem(
            index: index,
            initialDelay: const Duration(milliseconds: 60),
            staggerDelay: const Duration(milliseconds: 55),
            child: HonorProgressCard(
              userHonor: userHonor,
              honorName: honor.name,
              onTap: () {
                // Navigate to detail
              },
            ),
          );
        },
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  final Color bgColor;

  const _StatMini({
    required this.value,
    required this.label,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SacCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            AnimatedCounter(
              value: value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: context.sac.textSecondary,
              ),
              textAlign: TextAlign.center,
              // Fix 2.1: guard against overflow on very narrow phones
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
