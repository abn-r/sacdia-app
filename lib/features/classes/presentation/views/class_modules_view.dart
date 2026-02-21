import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/classes_providers.dart';
import '../widgets/module_expansion_tile.dart';

/// Vista de módulos de clase - Estilo "Scout Vibrante"
///
/// AppBar indigo, lista de ModuleExpansionTile con SacCard,
/// SnackBars flotantes para feedback.
class ClassModulesView extends ConsumerWidget {
  final int classId;

  const ClassModulesView({
    super.key,
    required this.classId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modulesAsync = ref.watch(classModulesProvider(classId));
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: AppBar(
        title: const Text('Módulos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: modulesAsync.when(
        data: (modules) {
          if (modules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedCheckList,
                      size: 56, color: AppColors.lightTextTertiary),
                  const SizedBox(height: 12),
                  Text(
                    'No hay módulos disponibles',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(classModulesProvider(classId));
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              itemCount: modules.length,
              itemBuilder: (context, index) {
                final module = modules[index];

                return ModuleExpansionTile(
                  module: module,
                  onSectionToggle: (sectionId, isCompleted) async {
                    final userId = authState.value?.id;
                    if (userId == null) return;

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

                    ref.invalidate(classModulesProvider(classId));

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isCompleted
                                ? 'Sección completada'
                                : 'Sección marcada como pendiente',
                          ),
                          backgroundColor: isCompleted
                              ? AppColors.secondary
                              : AppColors.accent,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
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
                HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                    size: 56, color: AppColors.error),
                const SizedBox(height: 16),
                Text(
                  'Error al cargar módulos',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: TextStyle(
                      fontSize: 14, color: AppColors.lightTextSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SacButton.primary(
                  text: 'Reintentar',
                  icon: HugeIcons.strokeRoundedRefresh,
                  onPressed: () {
                    ref.invalidate(classModulesProvider(classId));
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
