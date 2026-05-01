import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../data/models/disease_model.dart';
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
      title: 'post_registration.health.diseases.delete_dialog_title'.tr(),
      content: 'post_registration.health.diseases.delete_dialog_content'
          .tr(namedArgs: {'name': diseaseName}),
      confirmLabel: 'common.delete'.tr(),
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
              content: Text(
                  'post_registration.health.diseases.delete_success'.tr()),
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
                'post_registration.health.diseases.delete_error'
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
    // Seed selection state the first time user diseases load from the API.
    // The guard `prev?.value == null` ensures this only fires once on
    // the loading→data transition, not on every rebuild. Because
    // userDiseasesProvider is .autoDispose, it resets when the screen is
    // left, so re-entering the screen will re-seed correctly.
    ref.listen<AsyncValue<List<DiseaseModel>>>(
      userDiseasesProvider,
      (prev, next) {
        if (prev?.value == null && next.value != null) {
          ref.read(selectedDiseasesProvider.notifier).state =
              next.value!.map((d) => d.id).toList();
        }
      },
    );

    final diseasesAsync = ref.watch(diseasesCatalogProvider);
    final userDiseasesAsync = ref.watch(userDiseasesProvider);
    final selectedIds = ref.watch(selectedDiseasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('post_registration.health.diseases.title'.tr()),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
            onPressed: () =>
                ref.read(userDiseasesProvider.notifier).refresh(),
            tooltip:
                'post_registration.health.diseases.refresh_tooltip'.tr(),
          ),
          TextButton.icon(
            onPressed: () async {
              final ids = ref.read(selectedDiseasesProvider);
              await ref
                  .read(userDiseasesProvider.notifier)
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
              Text('post_registration.health.diseases.load_error'
                  .tr(namedArgs: {'error': error.toString()})),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 20),
                label: Text('common.retry'.tr()),
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
                        'post_registration.health.diseases.info_text'.tr(),
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
                        'post_registration.health.diseases.registered_label'
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
                  searchHint:
                      'post_registration.health.diseases.search_hint'.tr(),
                  hasNoneOption: true,
                  noneOptionLabel:
                      'post_registration.health.diseases.none_option'.tr(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
