import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../providers/personal_info_providers.dart';
import '../../data/models/medicine_model.dart';
import '../widgets/searchable_selection_list.dart';

/// Vista para seleccionar y gestionar medicamentos del usuario.
/// Pre-carga los medicamentos existentes del usuario al inicializarse.
class MedicinesSelectionView extends ConsumerStatefulWidget {
  const MedicinesSelectionView({super.key});

  @override
  ConsumerState<MedicinesSelectionView> createState() =>
      _MedicinesSelectionViewState();
}

class _MedicinesSelectionViewState
    extends ConsumerState<MedicinesSelectionView> {
  @override
  void initState() {
    super.initState();
    // Pre-cargar medicamentos del usuario al entrar a la vista.
    Future.microtask(() {
      ref.read(userMedicinesProvider.notifier).refresh();
    });
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    int medicineId,
    String medicineName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'post_registration.health.medicines.delete_dialog_title'.tr(),
      content: 'post_registration.health.medicines.delete_dialog_content'
          .tr(namedArgs: {'name': medicineName}),
      confirmLabel: 'common.delete'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref
            .read(userMedicinesProvider.notifier)
            .deleteMedicine(medicineId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'post_registration.health.medicines.delete_success'.tr()),
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
              content: Text(
                'post_registration.health.medicines.delete_error'
                    .tr(namedArgs: {'error': e.toString()}),
              ),
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
    // Seed selection state the first time user medicines load from the API.
    // The guard `prev?.value == null` ensures this only fires once on
    // the loading→data transition, not on every rebuild. Because
    // userMedicinesProvider is .autoDispose, it resets when the screen is
    // left, so re-entering the screen will re-seed correctly.
    ref.listen<AsyncValue<List<MedicineModel>>>(
      userMedicinesProvider,
      (prev, next) {
        if (prev?.value == null && next.value != null) {
          ref.read(selectedMedicinesProvider.notifier).state =
              next.value!.map((m) => m.id).toList();
        }
      },
    );

    final medicinesAsync = ref.watch(medicinesCatalogProvider);
    final userMedicinesAsync = ref.watch(userMedicinesProvider);
    final selectedIds = ref.watch(selectedMedicinesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('post_registration.health.medicines.title'.tr()),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
            onPressed: () =>
                ref.read(userMedicinesProvider.notifier).refresh(),
            tooltip:
                'post_registration.health.medicines.refresh_tooltip'.tr(),
          ),
          TextButton.icon(
            onPressed: () async {
              final ids = ref.read(selectedMedicinesProvider);
              await ref
                  .read(userMedicinesProvider.notifier)
                  .saveAll(ids);
              if (context.mounted) Navigator.of(context).pop();
            },
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedTick02,
              size: 20,
            ),
            label: Text('common.save'.tr()),
          ),
        ],
      ),
      body: medicinesAsync.when(
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
              Text('post_registration.health.medicines.load_error'
                  .tr(namedArgs: {'error': error.toString()})),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 20),
                label: Text('common.retry'.tr()),
                onPressed: () => ref.refresh(medicinesCatalogProvider),
              ),
            ],
          ),
        ),
        data: (medicines) {
          final items = medicines
              .map((medicine) => SelectableItem(
                    id: medicine.id,
                    name: medicine.name,
                    isSelected: selectedIds.contains(medicine.id),
                  ))
              .toList();

          // Medicamentos actualmente guardados en la API
          final savedMedicines = userMedicinesAsync.valueOrNull ?? [];

          return Column(
            children: [
              // Información
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: AppColors.secondaryLight,
                child: Row(
                  children: [
                    HugeIcon(
                        icon: HugeIcons.strokeRoundedInformationCircle,
                        color: AppColors.secondaryDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'post_registration.health.medicines.info_text'.tr(),
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.secondaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Medicamentos guardados con botón de eliminar
              if (userMedicinesAsync.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: SacLoadingSmall(),
                )
              else if (savedMedicines.isNotEmpty) ...[
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'post_registration.health.medicines.registered_label'
                            .tr(),
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
                        children: savedMedicines.map((medicine) {
                          return Chip(
                            label: Text(medicine.name),
                            backgroundColor: AppColors.secondaryLight,
                            labelStyle: TextStyle(
                              color: AppColors.secondaryDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            side: BorderSide(
                              color: AppColors.secondary.withValues(alpha: 0.4),
                            ),
                            deleteIcon: HugeIcon(
                              icon: HugeIcons.strokeRoundedDelete02,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            onDeleted: () => _showDeleteConfirmation(
                              context,
                              medicine.id,
                              medicine.name,
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
                    ref.read(selectedMedicinesProvider.notifier).state = ids;
                  },
                  searchHint:
                      'post_registration.health.medicines.search_hint'.tr(),
                  hasNoneOption: true,
                  noneOptionLabel:
                      'post_registration.health.medicines.none_option'.tr(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
