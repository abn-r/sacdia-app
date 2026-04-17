import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../data/models/allergy_model.dart';
import '../providers/personal_info_providers.dart';
import '../widgets/searchable_selection_list.dart';

/// Vista para seleccionar y gestionar alergias del usuario.
/// Pre-carga las alergias existentes del usuario al inicializarse.
class AllergiesSelectionView extends ConsumerStatefulWidget {
  const AllergiesSelectionView({super.key});

  @override
  ConsumerState<AllergiesSelectionView> createState() =>
      _AllergiesSelectionViewState();
}

class _AllergiesSelectionViewState
    extends ConsumerState<AllergiesSelectionView> {
  @override
  void initState() {
    super.initState();
    // Pre-cargar alergias del usuario al entrar a la vista.
    Future.microtask(() {
      ref.read(userAllergiesProvider.notifier).refresh();
    });
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    int allergyId,
    String allergyName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'Eliminar Alergia',
      content: '¿Estás seguro de que deseas eliminar "$allergyName"?',
      confirmLabel: 'Eliminar',
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(userAllergiesProvider.notifier)
            .deleteAllergy(allergyId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Alergia eliminada correctamente'),
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
    // Seed selection state the first time user allergies load from the API.
    // The guard `prev?.value == null` ensures this only fires once on
    // the loading→data transition, not on every rebuild. Because
    // userAllergiesProvider is .autoDispose, it resets when the screen is
    // left, so re-entering the screen will re-seed correctly.
    ref.listen<AsyncValue<List<AllergyModel>>>(
      userAllergiesProvider,
      (prev, next) {
        if (prev?.value == null && next.value != null) {
          ref.read(selectedAllergiesProvider.notifier).state =
              next.value!.map((a) => a.id).toList();
        }
      },
    );

    final allergiesAsync = ref.watch(allergiesCatalogProvider);
    final userAllergiesAsync = ref.watch(userAllergiesProvider);
    final selectedIds = ref.watch(selectedAllergiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alergias'),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
            onPressed: () =>
                ref.read(userAllergiesProvider.notifier).refresh(),
            tooltip: 'Actualizar',
          ),
          TextButton.icon(
            onPressed: () async {
              final ids = ref.read(selectedAllergiesProvider);
              await ref
                  .read(userAllergiesProvider.notifier)
                  .saveAll(ids);
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              size: 20,
            ),
            label: const Text('Guardar'),
          ),
        ],
      ),
      body: allergiesAsync.when(
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
                onPressed: () => ref.refresh(allergiesCatalogProvider),
              ),
            ],
          ),
        ),
        data: (allergies) {
          final items = allergies
              .map((allergy) => SelectableItem(
                    id: allergy.id,
                    name: allergy.name,
                    isSelected: selectedIds.contains(allergy.id),
                  ))
              .toList();

          // Alergias actualmente guardadas en la API
          final savedAllergies = userAllergiesAsync.valueOrNull ?? [];

          return Column(
            children: [
              // Información
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.primaryLight,
                child: Row(
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: AppColors.primaryDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Selecciona todas las alergias que tengas. Si no tienes ninguna, marca "Ninguna".',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Alergias guardadas con botón de eliminar
              if (userAllergiesAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SacLoadingSmall(),
                )
              else if (savedAllergies.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alergias registradas',
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
                        children: savedAllergies.map((allergy) {
                          return Chip(
                            label: Text(allergy.name),
                            backgroundColor: AppColors.errorLight,
                            labelStyle: TextStyle(
                              color: AppColors.errorDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.4),
                            ),
                            deleteIcon: HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete02,
                              size: 16,
                              color: AppColors.error,
                            ),
                            onDeleted: () => _showDeleteConfirmation(
                              context,
                              allergy.id,
                              allergy.name,
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
                    ref.read(selectedAllergiesProvider.notifier).state = ids;
                  },
                  searchHint: 'Buscar alergia...',
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
