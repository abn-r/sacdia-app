import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
/// Cada enfermedad seleccionada muestra un input inline para el año de inicio.
class DiseasesSelectionView extends ConsumerStatefulWidget {
  const DiseasesSelectionView({super.key});

  @override
  ConsumerState<DiseasesSelectionView> createState() =>
      _DiseasesSelectionViewState();
}

class _DiseasesSelectionViewState extends ConsumerState<DiseasesSelectionView> {
  /// Mapa local id → since_year para las enfermedades seleccionadas.
  final Map<int, int?> _sinceYearMap = {};
  bool _sinceYearSeeded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userDiseasesProvider.notifier).refresh();
    });
  }

  void _seedSinceYear(List<DiseaseModel> serverDiseases) {
    if (_sinceYearSeeded) return;
    _sinceYearSeeded = true;
    for (final d in serverDiseases) {
      if (d.sinceYear != null) _sinceYearMap[d.id] = d.sinceYear;
    }
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
        await ref.read(userDiseasesProvider.notifier).deleteDisease(diseaseId);
        setState(() {
          _sinceYearMap.remove(diseaseId);
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('post_registration.health.diseases.delete_success'.tr()),
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
    ref.listen<AsyncValue<List<DiseaseModel>>>(
      userDiseasesProvider,
      (prev, next) {
        if (prev?.value == null && next.value != null) {
          ref.read(selectedDiseasesProvider.notifier).state =
              next.value!.map((d) => d.id).toList();
          _seedSinceYear(next.value!);
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
            onPressed: () {
              setState(() => _sinceYearSeeded = false);
              ref.read(userDiseasesProvider.notifier).refresh();
            },
            tooltip: 'post_registration.health.diseases.refresh_tooltip'.tr(),
          ),
          TextButton.icon(
            onPressed: () async {
              final ids = ref.read(selectedDiseasesProvider);
              final entries = ids
                  .map((id) => DiseaseEntry(
                        id: id,
                        sinceYear: _sinceYearMap[id],
                      ))
                  .toList();
              await ref.read(userDiseasesProvider.notifier).saveAll(entries);
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

              // Lista de selección con editor inline de año
              Expanded(
                child: _DiseasesListWithYear(
                  items: items,
                  selectedIds: selectedIds,
                  sinceYearMap: _sinceYearMap,
                  onSelectionChanged: (ids) {
                    ref.read(selectedDiseasesProvider.notifier).state = ids;
                  },
                  onSinceYearChanged: (id, year) {
                    setState(() {
                      _sinceYearMap[id] = year;
                    });
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

/// Lista con búsqueda + input inline de año para enfermedades seleccionadas.
class _DiseasesListWithYear extends StatefulWidget {
  final List<SelectableItem> items;
  final List<int> selectedIds;
  final Map<int, int?> sinceYearMap;
  final Function(List<int>) onSelectionChanged;
  final Function(int, int?) onSinceYearChanged;
  final String? searchHint;
  final bool hasNoneOption;
  final String noneOptionLabel;

  const _DiseasesListWithYear({
    required this.items,
    required this.selectedIds,
    required this.sinceYearMap,
    required this.onSelectionChanged,
    required this.onSinceYearChanged,
    this.searchHint,
    this.hasNoneOption = true,
    this.noneOptionLabel = 'Ninguna',
  });

  @override
  State<_DiseasesListWithYear> createState() => _DiseasesListWithYearState();
}

class _DiseasesListWithYearState extends State<_DiseasesListWithYear> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late List<SelectableItem> _items;

  /// Mapa de controllers de TextField para cada item seleccionado
  final Map<int, TextEditingController> _yearControllers = {};

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
  void didUpdateWidget(_DiseasesListWithYear oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIds != widget.selectedIds ||
        oldWidget.items != widget.items) {
      _initializeItems();
    }
  }

  TextEditingController _controllerFor(int id) {
    return _yearControllers.putIfAbsent(id, () {
      final existing = widget.sinceYearMap[id];
      return TextEditingController(
          text: existing != null ? existing.toString() : '');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _yearControllers.values) {
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
                        // Inline year input cuando está seleccionada
                        if (isSelected)
                          _SinceYearInlineEditor(
                            controller: _controllerFor(item.id),
                            onChanged: (year) =>
                                widget.onSinceYearChanged(item.id, year),
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

/// Editor inline de año (TextField numérico de 4 dígitos, validado 1900–año actual).
class _SinceYearInlineEditor extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<int?> onChanged;

  const _SinceYearInlineEditor({
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_SinceYearInlineEditor> createState() => _SinceYearInlineEditorState();
}

class _SinceYearInlineEditorState extends State<_SinceYearInlineEditor> {
  String? _errorText;

  void _validate(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorText = null);
      widget.onChanged(null);
      return;
    }

    final year = int.tryParse(trimmed);
    final currentYear = DateTime.now().year;

    if (year == null || year < 1900 || year > currentYear) {
      setState(() {
        _errorText =
            'post_registration.diseases.since_year_invalid'.tr();
      });
      widget.onChanged(null);
    } else {
      setState(() => _errorText = null);
      widget.onChanged(year);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'post_registration.diseases.since_year_label'.tr(),
          hintText: 'post_registration.diseases.since_year_hint'.tr(),
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
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(4),
        ],
        onChanged: _validate,
      ),
    );
  }
}
