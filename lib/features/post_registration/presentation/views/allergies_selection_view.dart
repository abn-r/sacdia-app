import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/personal_info_providers.dart';
import '../widgets/searchable_selection_list.dart';

/// Vista para seleccionar alergias del usuario
class AllergiesSelectionView extends ConsumerWidget {
  const AllergiesSelectionView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allergiesAsync = ref.watch(allergiesCatalogProvider);
    final selectedIds = ref.watch(selectedAllergiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alergias'),
        actions: [
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
