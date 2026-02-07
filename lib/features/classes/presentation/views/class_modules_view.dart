import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/classes_providers.dart';
import '../widgets/module_expansion_tile.dart';

/// Vista de módulos de una clase progresiva
class ClassModulesView extends ConsumerWidget {
  final int classId;

  const ClassModulesView({
    Key? key,
    required this.classId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(classModulesProvider(classId));
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulos de la Clase'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: modulesAsync.when(
        data: (modules) {
          if (modules.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list_alt_outlined,
                    size: 80,
                    color: AppColors.lightTextSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No hay módulos disponibles',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(classModulesProvider(classId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];

                return ModuleExpansionTile(
                  module: module,
                  onSectionToggle: (sectionId, isCompleted) async {
                    final userId = authState.value?.id;
                    if (userId == null) return;

                    // Actualizar progreso
                    await ref
                        .read(classProgressNotifierProvider.notifier)
                        .updateProgress(
                          userId,
                          classId,
                          {
                            'section_id': sectionId,
                            'is_completed': isCompleted,
                          },
                        );

                    // Refrescar módulos
                    ref.invalidate(classModulesProvider(classId));

                    // Mostrar mensaje
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isCompleted
                                ? 'Sección completada'
                                : 'Sección marcada como pendiente',
                          ),
                          backgroundColor: isCompleted
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      );
                    }
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
                'Error al cargar módulos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: const TextStyle(color: AppColors.lightTextSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  ref.invalidate(classModulesProvider(classId));
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
