import 'package:flutter/material.dart';

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
  final String searchHint;
  final bool hasNoneOption;
  final String noneOptionLabel;

  const SearchableSelectionList({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.onSelectionChanged,
    this.searchHint = 'Buscar...',
    this.hasNoneOption = true,
    this.noneOptionLabel = 'Ninguna',
  });

  @override
  State<SearchableSelectionList> createState() => _SearchableSelectionListState();
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
              hintText: widget.searchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
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
              fillColor: Colors.grey[100],
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
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No se encontraron resultados',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
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
                          fontWeight: isNoneOption ? FontWeight.bold : FontWeight.normal,
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
            color: Colors.grey[100],
            border: Border(
              top: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _getSelectionCountText(),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_items.any((i) => i.isSelected && i.id != _noneOptionId))
                TextButton.icon(
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Limpiar'),
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
    final count = _items.where((i) => i.isSelected && i.id != _noneOptionId).length;

    if (count == 0) {
      return 'Ningún elemento seleccionado';
    } else if (count == 1) {
      return '1 elemento seleccionado';
    } else {
      return '$count elementos seleccionados';
    }
  }
}
