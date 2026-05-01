import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../../core/theme/sac_colors.dart';

/// Item seleccionable con checkbox
class SelectableItem {
  final int id;
  final String name;
  bool isSelected;

  SelectableItem({
    required this.id,
    required this.name,
    this.isSelected = false,
  });
}

/// Widget reutilizable para lista con búsqueda y selección múltiple
class SearchableSelectionList extends StatefulWidget {
  final List<SelectableItem> items;
  final List<int> selectedIds;
  final Function(List<int>) onSelectionChanged;
  final String? searchHint;
  final bool hasNoneOption;
  final String noneOptionLabel;

  const SearchableSelectionList({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.searchHint,
    this.hasNoneOption = true,
    this.noneOptionLabel = 'Ninguna',
  });

  @override
  State<SearchableSelectionList> createState() =>
      _SearchableSelectionListState();
}

class _SearchableSelectionListState extends State<SearchableSelectionList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late List<SelectableItem> _items;

  // ID especial para la opción "Ninguna"
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

    // Agregar opción "Ninguna" al inicio si está habilitada
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
  void didUpdateWidget(SearchableSelectionList oldWidget) {
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

    return _items.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _handleItemToggle(SelectableItem item) {
    setState(() {
      if (item.id == _noneOptionId) {
        // Si selecciona "Ninguna", deseleccionar todo lo demás
        for (var i in _items) {
          i.isSelected = i.id == _noneOptionId;
        }
      } else {
        // Si selecciona cualquier otro, deseleccionar "Ninguna"
        item.isSelected = !item.isSelected;
        final noneItem = _items.firstWhere(
          (i) => i.id == _noneOptionId,
          orElse: () => item,
        );
        if (noneItem.id == _noneOptionId) {
          noneItem.isSelected = false;
        }
      }

      // Notificar cambios (excluir "Ninguna" de los IDs)
      final selectedIds = _items
          .where((i) => i.isSelected && i.id != _noneOptionId)
          .map((i) => i.id)
          .toList();

      widget.onSelectionChanged(selectedIds);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = _filteredItems;

    return Column(
      children: [
        // Campo de búsqueda
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

        // Lista de items
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

                    return ListTile(
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
                    );
                  },
                ),
        ),

        // Contador de seleccionados
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.sac.surfaceVariant,
            border: Border(
              top: BorderSide(color: context.sac.border),
            ),
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

  String _getSelectionCountText() {
    final count =
        _items.where((i) => i.isSelected && i.id != _noneOptionId).length;

    if (count == 0) {
      return tr('common.none_selected');
    } else if (count == 1) {
      return tr('common.items_selected_one');
    } else {
      return tr('common.items_selected_other', namedArgs: {'count': '$count'});
    }
  }
}
