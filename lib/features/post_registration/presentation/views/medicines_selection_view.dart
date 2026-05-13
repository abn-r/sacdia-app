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
/// Cada medicamento seleccionado muestra un input inline para la dosis.
class MedicinesSelectionView extends ConsumerStatefulWidget {
  const MedicinesSelectionView({super.key});

  @override
  ConsumerState<MedicinesSelectionView> createState() =>
      _MedicinesSelectionViewState();
}

class _MedicinesSelectionViewState
    extends ConsumerState<MedicinesSelectionView> {
  /// Mapa local id → dosis para los medicamentos seleccionados.
  final Map<int, String?> _doseMap = {};
  bool _doseSeeded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userMedicinesProvider.notifier).refresh();
    });
  }

  void _seedDose(List<MedicineModel> serverMedicines) {
    if (_doseSeeded) return;
    _doseSeeded = true;
    for (final m in serverMedicines) {
      if (m.dose != null) _doseMap[m.id] = m.dose;
    }
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
        setState(() {
          _doseMap.remove(medicineId);
        });
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
    ref.listen<AsyncValue<List<MedicineModel>>>(
      userMedicinesProvider,
      (prev, next) {
        if (prev?.value == null && next.value != null) {
          ref.read(selectedMedicinesProvider.notifier).state =
              next.value!.map((m) => m.id).toList();
          _seedDose(next.value!);
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
            onPressed: () {
              setState(() => _doseSeeded = false);
              ref.read(userMedicinesProvider.notifier).refresh();
            },
            tooltip: 'post_registration.health.medicines.refresh_tooltip'.tr(),
          ),
          TextButton.icon(
            onPressed: () async {
              final ids = ref.read(selectedMedicinesProvider);
              final entries = ids
                  .map((id) => MedicineEntry(
                        id: id,
                        dose: _doseMap[id],
                      ))
                  .toList();
              await ref.read(userMedicinesProvider.notifier).saveAll(entries);
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

              // Lista de selección con editor inline de dosis
              Expanded(
                child: _MedicinesListWithDose(
                  items: items,
                  selectedIds: selectedIds,
                  doseMap: _doseMap,
                  onSelectionChanged: (ids) {
                    ref.read(selectedMedicinesProvider.notifier).state = ids;
                  },
                  onDoseChanged: (id, dose) {
                    setState(() {
                      _doseMap[id] = dose;
                    });
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

/// Lista con búsqueda + input inline de dosis para medicamentos seleccionados.
class _MedicinesListWithDose extends StatefulWidget {
  final List<SelectableItem> items;
  final List<int> selectedIds;
  final Map<int, String?> doseMap;
  final Function(List<int>) onSelectionChanged;
  final Function(int, String?) onDoseChanged;
  final String? searchHint;
  final bool hasNoneOption;
  final String noneOptionLabel;

  const _MedicinesListWithDose({
    required this.items,
    required this.selectedIds,
    required this.doseMap,
    required this.onSelectionChanged,
    required this.onDoseChanged,
    this.searchHint,
    this.hasNoneOption = true,
    this.noneOptionLabel = 'Ninguno',
  });

  @override
  State<_MedicinesListWithDose> createState() => _MedicinesListWithDoseState();
}

class _MedicinesListWithDoseState extends State<_MedicinesListWithDose> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late List<SelectableItem> _items;
  final Map<int, TextEditingController> _doseControllers = {};

  static const int _noneOptionId = -1;

  @override
  void initState() {
    super.initState();
    _initializeItems();
  }

  void _initializeItems() {
    _items = widget.items.map((item) {
      return SelectableItem(
        id: item.id,
        name: item.name,
        isSelected: widget.selectedIds.contains(item.id),
      );
    }).toList();

    if (widget.hasNoneOption) {
      _items.insert(
        0,
        SelectableItem(
          id: _noneOptionId,
          name: widget.noneOptionLabel,
          isSelected: widget.selectedIds.isEmpty,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(_MedicinesListWithDose oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIds != widget.selectedIds ||
        oldWidget.items != widget.items) {
      _initializeItems();
    }
  }

  TextEditingController _controllerFor(int id) {
    return _doseControllers.putIfAbsent(id, () {
      final existing = widget.doseMap[id];
      return TextEditingController(text: existing ?? '');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _doseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<SelectableItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items
        .where((item) =>
            item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _handleItemToggle(SelectableItem item) {
    setState(() {
      if (item.id == _noneOptionId) {
        for (var i in _items) {
          i.isSelected = i.id == _noneOptionId;
        }
      } else {
        item.isSelected = !item.isSelected;
        final noneItem = _items.firstWhere(
          (i) => i.id == _noneOptionId,
          orElse: () => item,
        );
        if (noneItem.id == _noneOptionId) noneItem.isSelected = false;
      }

      final selectedIds = _items
          .where((i) => i.isSelected && i.id != _noneOptionId)
          .map((i) => i.id)
          .toList();

      widget.onSelectionChanged(selectedIds);
    });
  }

  String _getSelectionCountText() {
    final count =
        _items.where((i) => i.isSelected && i.id != _noneOptionId).length;
    if (count == 0) return tr('common.none_selected');
    if (count == 1) return tr('common.items_selected_one');
    return tr('common.items_selected_other', namedArgs: {'count': '$count'});
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.searchHint ?? tr('common.search'),
              prefixIcon:
                  HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 22),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01, size: 22),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: context.sac.surfaceVariant,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: HugeIcons.strokeRoundedSearchMinus,
                        size: 64,
                        color: context.sac.textTertiary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr('common.no_results'),
                        style: TextStyle(
                          fontSize: 16,
                          color: context.sac.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    final isNoneOption = item.id == _noneOptionId;
                    final isSelected = item.isSelected && !isNoneOption;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontWeight: isNoneOption
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          leading: Checkbox(
                            value: item.isSelected,
                            onChanged: (_) => _handleItemToggle(item),
                          ),
                          onTap: () => _handleItemToggle(item),
                        ),
                        // Inline dose input cuando está seleccionado
                        if (isSelected)
                          _DoseInlineEditor(
                            controller: _controllerFor(item.id),
                            onChanged: (dose) =>
                                widget.onDoseChanged(item.id, dose),
                          ),
                      ],
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.sac.surfaceVariant,
            border: Border(top: BorderSide(color: context.sac.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getSelectionCountText(),
                style: TextStyle(
                  fontSize: 14,
                  color: context.sac.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_items.any((i) => i.isSelected && i.id != _noneOptionId))
                TextButton.icon(
                  icon:
                      HugeIcon(icon: HugeIcons.strokeRoundedCancel02, size: 20),
                  label: Text(tr('common.clear')),
                  onPressed: () {
                    setState(() {
                      for (var item in _items) {
                        item.isSelected = item.id == _noneOptionId;
                      }
                      widget.onSelectionChanged([]);
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Editor inline de dosis (TextField libre, max 255 chars, opcional).
class _DoseInlineEditor extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String?> onChanged;

  const _DoseInlineEditor({
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_DoseInlineEditor> createState() => _DoseInlineEditorState();
}

class _DoseInlineEditorState extends State<_DoseInlineEditor> {
  String? _errorText;

  void _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged(null);
      return;
    }

    if (trimmed.length > 255) {
      setState(() {
        _errorText = 'post_registration.medicines.dose_too_long'.tr();
      });
      // Still notify with truncated value to avoid silent data loss
      widget.onChanged(null);
    } else {
      setState(() => _errorText = null);
      widget.onChanged(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'post_registration.medicines.dose_label'.tr(),
          hintText: 'post_registration.medicines.dose_hint'.tr(),
          errorText: _errorText,
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          suffixText: 'common.optional'.tr(),
          suffixStyle: TextStyle(
            fontSize: 11,
            color: context.sac.textTertiary,
          ),
        ),
        maxLength: 255,
        buildCounter: (context,
                {required currentLength,
                required isFocused,
                required maxLength}) =>
            null, // hide the counter
        onChanged: _validate,
      ),
    );
  }
}
