import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/honors_providers.dart';
import '../../domain/usecases/get_honors.dart';

/// Vista de detalle de una especialidad
class HonorDetailView extends ConsumerWidget {
  final int honorId;

  const HonorDetailView({
    Key? key,
    required this.honorId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honorAsync = ref.watch(honorsProvider(GetHonorsParams()));
    final authState = ref.watch(authNotifierProvider);
    final enrollmentState = ref.watch(honorEnrollmentNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle de Especialidad'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: honorAsync.when(
        data: (honors) {
          final honor = honors.firstWhere(
            (h) => h.id == honorId,
            orElse: () => throw Exception('Especialidad no encontrada'),
          );

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen de la especialidad
                if (honor.imageUrl != null)
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(honor.imageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 200,
                    color: AppColors.primaryBlue.withOpacity(0.2),
                    child: const Icon(
                      Icons.workspace_premium,
                      size: 80,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                const SizedBox(height: 16),
                // Información de la especialidad
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        honor.name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (honor.skillLevel != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              size: 20,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Nivel de habilidad: ${honor.skillLevel}',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (honor.description != null) ...[
                        Text(
                          'Descripción',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          honor.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      // Sección de requisitos (placeholder)
                      Text(
                        'Requisitos',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Los requisitos específicos de esta especialidad se mostrarán aquí.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Botón de inscripción
                      SizedBox(
                        width: double.infinity,
                        child: enrollmentState.when(
                          data: (userHonor) {
                            if (userHonor != null) {
                              return ElevatedButton.icon(
                                onPressed: null,
                                icon: const Icon(Icons.check),
                                label: const Text('Ya estás inscrito'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                              );
                            }

                            return ElevatedButton.icon(
                              onPressed: () async {
                                final userId = authState.value?.id;
                                if (userId == null) return;

                                await ref
                                    .read(honorEnrollmentNotifierProvider.notifier)
                                    .enrollInHonor(userId, honorId);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Inscripción exitosa'),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  ref.invalidate(userHonorsProvider);
                                }
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Inscribirme'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryBlue,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          error: (error, stack) => ElevatedButton.icon(
                            onPressed: () async {
                              final userId = authState.value?.id;
                              if (userId == null) return;

                              await ref
                                  .read(honorEnrollmentNotifierProvider.notifier)
                                  .enrollInHonor(userId, honorId);
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar inscripción'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
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
                'Error al cargar detalle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(honorsProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
