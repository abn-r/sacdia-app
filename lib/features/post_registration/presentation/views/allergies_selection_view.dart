import 'package:easy_localization/easy_localization.dart';
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
/// Cada alergia seleccionada muestra un selector inline de severidad.
class AllergiesSelectionView extends ConsumerStatefulWidget {
  const AllergiesSelectionView({super.key});

  @override
  ConsumerState<AllergiesSelectionView> createState() =>
      _AllergiesSelectionViewState();
}

class _AllergiesSelectionViewState
    extends ConsumerState<AllergiesSelectionView> {
  /// Mapa local id → severidad para las alergias seleccionadas en esta sesión.
  /// Se inicializa con los datos del servidor al cargar.
  final Map<int, AllergySeverity> _severityMap = {};
  bool _severitySeeded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(userAllergiesProvider.notifier).refresh();
    });
  }

  /// Sincroniza _severityMap con los datos del servidor (solo 1ª vez).
  void _seedSeverity(List<AllergyModel> serverAllergies) {
    if (_severitySeeded) return;
    _severitySeeded = true;
    for (final a in serverAllergies) {
      _severityMap[a.id] = a.severity;
    }
  }

  AllergySeverity _severityFor(int id) =>
      _severityMap[id] ?? AllergySeverity.leve;

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    int allergyId,
    String allergyName,
  ) async {
    final confirmed = await SacDialog.show(
      context,
      title: 'post_registration.health.allergies.delete_dialog_title'.tr(),
      content: 'post_registration.health.allergies.delete_dialog_content'
          .tr(namedArgs: {'name': allergyName}),
      confirmLabel: 'common.delete'.tr(),
      confirmIsDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(userAllergiesProvider.notifier).deleteAllergy(allergyId);
        setState(() {
          _severityMap.remove(allergyId);
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'post_registration.health.allergies.delete_success'.tr()),
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
                'post_registration.health.allergies.delete_error'
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
    // Seed selection state + severity the first time user allergies load.
    ref.listen<AsyncValue<List<AllergyModel>>>(
      userAllergiesProvider,
      (prev, next) {
        if (prev?.value == null && next.value != null) {
          ref.read(selectedAllergiesProvider.notifier).state =
              next.value!.map((a) => a.id).toList();
          _seedSeverity(next.value!);
        }
      },
    );

    final allergiesAsync = ref.watch(allergiesCatalogProvider);
    final userAllergiesAsync = ref.watch(userAllergiesProvider);
    final selectedIds = ref.watch(selectedAllergiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('post_registration.health.allergies.title'.tr()),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24),
            onPressed: () {
              setState(() => _severitySeeded = false);
              ref.read(userAllergiesProvider.notifier).refresh();
            },
            tooltip: 'post_registration.health.allergies.refresh_tooltip'.tr(),
          ),
          TextButton.icon(
            onPressed: () async {
              final ids = ref.read(selectedAllergiesProvider);
              // Build entries with severity; default leve if not set
              final entries = ids
                  .map((id) => AllergyEntry(
                        id: id,
                        severity: _severityFor(id),
                      ))
                  .toList();
              await ref.read(userAllergiesProvider.notifier).saveAll(entries);
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
              Text('post_registration.health.allergies.load_error'
                  .tr(namedArgs: {'error': error.toString()})),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 20),
                label: Text('common.retry'.tr()),
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
                        'post_registration.health.allergies.info_text'.tr(),
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
                        'post_registration.health.allergies.registered_label'
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

              // Lista de selección con editor inline de severidad
              Expanded(
                child: _AllergiesListWithSeverity(
                  items: items,
                  selectedIds: selectedIds,
                  severityMap: _severityMap,
                  onSelectionChanged: (ids) {
                    ref.read(selectedAllergiesProvider.notifier).state = ids;
                  },
                  onSeverityChanged: (id, severity) {
                    setState(() {
                      _severityMap[id] = severity;
                    });
                  },
                  searchHint:
                      'post_registration.health.allergies.search_hint'.tr(),
                  hasNoneOption: true,
                  noneOptionLabel:
                      'post_registration.health.allergies.none_option'.tr(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Lista con búsqueda + selector inline de severidad para alergias seleccionadas.
class _AllergiesListWithSeverity extends StatefulWidget {
  final List<SelectableItem> items;
  final List<int> selectedIds;
  final Map<int, AllergySeverity> severityMap;
  final Function(List<int>) onSelectionChanged;
  final Function(int, AllergySeverity) onSeverityChanged;
  final String? searchHint;
  final bool hasNoneOption;
  final String noneOptionLabel;

  const _AllergiesListWithSeverity({
    required this.items,
    required this.selectedIds,
    required this.severityMap,
    required this.onSelectionChanged,
    required this.onSeverityChanged,
    this.searchHint,
    this.hasNoneOption = true,
    this.noneOptionLabel = 'Ninguna',
  });

  @override
  State<_AllergiesListWithSeverity> createState() =>
      _AllergiesListWithSeverityState();
}

class _AllergiesListWithSeverityState
    extends State<_AllergiesListWithSeverity> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late List<SelectableItem> _items;

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
  void didUpdateWidget(_AllergiesListWithSeverity oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIds != widget.selectedIds ||
        oldWidget.items != widget.items) {
      _initializeItems();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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
                        // Inline severity editor cuando está seleccionada
                        if (isSelected)
                          _SeverityInlineEditor(
                            selectedSeverity: widget.severityMap[item.id] ??
                                AllergySeverity.leve,
                            onChanged: (severity) =>
                                widget.onSeverityChanged(item.id, severity),
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

/// Editor inline de severidad con 3 opciones (SegmentedButton).
class _SeverityInlineEditor extends StatelessWidget {
  final AllergySeverity selectedSeverity;
  final ValueChanged<AllergySeverity> onChanged;

  const _SeverityInlineEditor({
    required this.selectedSeverity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'post_registration.allergies.severity_label'.tr(),
            style: TextStyle(
              fontSize: 12,
              color: context.sac.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<AllergySeverity>(
            segments: [
              ButtonSegment(
                value: AllergySeverity.leve,
                label: Text(
                  'profile.medical_info.severity.leve'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              ButtonSegment(
                value: AllergySeverity.media,
                label: Text(
                  'profile.medical_info.severity.media'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              ButtonSegment(
                value: AllergySeverity.alta,
                label: Text(
                  'profile.medical_info.severity.alta'.tr(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
            selected: {selectedSeverity},
            onSelectionChanged: (selection) {
              if (selection.isNotEmpty) onChanged(selection.first);
            },
            style: ButtonStyle(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}
