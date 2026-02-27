import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../providers/personal_info_providers.dart';
import '../widgets/searchable_selection_list.dart';

/// Vista para seleccionar y gestionar enfermedades del usuario.
/// Pre-carga las enfermedades existentes del usuario al inicializarse.
class DiseasesSelectionView extends ConsumerStatefulWidget {
  const DiseasesSelectionView({super.key});

  @override
  ConsumerState<DiseasesSelectionView> createState() =>
      _DiseasesSelectionViewState();
}

class _DiseasesSelectionViewState extends ConsumerState<DiseasesSelectionView> {
  @override
  void initState() {
    super.initState();
    // Pre-cargar enfermedades del usuario al entrar a la vista.
    // El notifier ya sincroniza selectedDiseasesProvider en su build().
    Future.microtask(() {
      ref.read(userDiseasesProvider.notifier).refresh();
    });
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    int diseaseId,
    String diseaseName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'Eliminar Enfermedad',
      content: '¿Estás seguro de que deseas eliminar "$diseaseName"?',
      confirmLabel: 'Eliminar',
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(userDiseasesProvider.notifier)
            .deleteDisease(diseaseId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Enfermedad eliminada correctamente'),
              backgroundColor: AppColors.secondary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: ${e.toString()}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final diseasesAsync = ref.watch(diseasesCatalogProvider);
    final userDiseasesAsync = ref.watch(userDiseasesProvider);
    final selectedIds = ref.watch(selectedDiseasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enfermedades'),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
            onPressed: () =>
                ref.read(userDiseasesProvider.notifier).refresh(),
            tooltip: 'Actualizar',
          ),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              size: 20,
            ),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: diseasesAsync.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                  icon: HugeIcons.strokeRoundedAlert02,
                  size: 48,
                  color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 20),
                label: const Text('Reintentar'),
                onPressed: () => ref.refresh(diseasesCatalogProvider),
              ),
            ],
          ),
        ),
        data: (diseases) {
          final items = diseases
              .map((disease) => SelectableItem(
                    id: disease.id,
                    name: disease.name,
                    isSelected: selectedIds.contains(disease.id),
                  ))
              .toList();

          // Enfermedades actualmente guardadas en la API
          final savedDiseases = userDiseasesAsync.valueOrNull ?? [];

          return Column(
            children: [
              // Información
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.accentLight,
                child: Row(
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: AppColors.accentDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Selecciona todas las enfermedades o condiciones médicas que tengas. Si no tienes ninguna, marca "Ninguna".',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.accentDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Enfermedades guardadas con botón de eliminar
              if (userDiseasesAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SacLoadingSmall(),
                )
              else if (savedDiseases.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enfermedades registradas',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.sac.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: savedDiseases.map((disease) {
                          return Chip(
                            label: Text(disease.name),
                            backgroundColor: AppColors.accentLight,
                            labelStyle: TextStyle(
                              color: AppColors.accentDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: AppColors.accent.withValues(alpha: 0.4),
                            ),
                            deleteIcon: HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete02,
                              size: 16,
                              color: AppColors.accent,
                            ),
                            onDeleted: () => _showDeleteConfirmation(
                              context,
                              disease.id,
                              disease.name,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
              ],

              // Lista de selección
              Expanded(
                child: SearchableSelectionList(
                  items: items,
                  selectedIds: selectedIds,
                  onSelectionChanged: (ids) {
                    ref.read(selectedDiseasesProvider.notifier).state = ids;
                  },
                  searchHint: 'Buscar enfermedad...',
                  hasNoneOption: true,
                  noneOptionLabel: 'Ninguna',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
