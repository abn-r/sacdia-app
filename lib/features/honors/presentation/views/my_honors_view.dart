import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/honors_providers.dart';
import '../widgets/honor_progress_card.dart';
import '../../domain/usecases/get_honors.dart';

/// Vista de mis especialidades
class MyHonorsView extends ConsumerWidget {
  const MyHonorsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userHonorsAsync = ref.watch(userHonorsProvider);
    final statsAsync = ref.watch(userHonorStatsProvider);
    final honorsAsync = ref.watch(honorsProvider(const GetHonorsParams()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Especialidades'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: Column(
        children: [
          // Estadísticas
          statsAsync.when(
            data: (stats) => Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    context,
                    'Total',
                    stats['total']?.toString() ?? '0',
                    Icons.workspace_premium,
                  ),
                  _buildStatItem(
                    context,
                    'En progreso',
                    stats['in_progress']?.toString() ?? '0',
                    Icons.hourglass_bottom,
                  ),
                  _buildStatItem(
                    context,
                    'Completadas',
                    stats['completed']?.toString() ?? '0',
                    Icons.check_circle,
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          const Divider(),
          // Lista de especialidades
          Expanded(
            child: userHonorsAsync.when(
              data: (userHonors) {
                if (userHonors.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.workspace_premium_outlined,
                          size: 80,
                          color: AppColors.lightTextSecondary,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No tienes especialidades',
                          style: TextStyle(
                            fontSize: 18,
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Inscríbete en el catálogo',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return honorsAsync.when(
                  data: (honors) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(userHonorsProvider);
                        ref.invalidate(userHonorStatsProvider);
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: userHonors.length,
                        itemBuilder: (context, index) {
                          final userHonor = userHonors[index];
                          final honor = honors.firstWhere(
                            (h) => h.id == userHonor.honorId,
                            orElse: () => throw Exception('Honor no encontrado'),
                          );

                          return HonorProgressCard(
                            userHonor: userHonor,
                            honorName: honor.name,
                            onTap: () {
                              // Navegar al detalle
                            },
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, stack) => Center(
                    child: Text('Error: $error'),
                  ),
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar especialidades',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(userHonorsProvider);
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye un item de estadística
  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 32, color: AppColors.primaryBlue),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
