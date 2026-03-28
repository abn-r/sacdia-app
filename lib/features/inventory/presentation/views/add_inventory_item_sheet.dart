import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/inventory_category.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';

/// Bottom sheet para agregar o editar un ítem de inventario.
///
/// Recibe [existing] cuando se edita un ítem existente.
class AddInventoryItemSheet extends ConsumerStatefulWidget {
  final InventoryItem? existing;

  const AddInventoryItemSheet({super.key, this.existing});

  @override
  ConsumerState<AddInventoryItemSheet> createState() =>
      _AddInventoryItemSheetState();
}

class _AddInventoryItemSheetState
    extends ConsumerState<AddInventoryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _serialController = TextEditingController();
  final _valueController = TextEditingController();
  final _locationController = TextEditingController();
  final _assignedToController = TextEditingController();
  final _notesController = TextEditingController();

  ItemCondition _condition = ItemCondition.bueno;
  InventoryCategory? _selectedCategory;
  DateTime? _purchaseDate;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existing!;
      _nameController.text = item.name;
      _descController.text = item.description ?? '';
      _quantityController.text = item.quantity.toString();
      _serialController.text = item.serialNumber ?? '';
      _valueController.text = item.estimatedValue?.toStringAsFixed(2) ?? '';
      _locationController.text = item.location ?? '';
      _assignedToController.text = item.assignedTo ?? '';
      _notesController.text = item.notes ?? '';
      _condition = item.condition;
      _selectedCategory = item.category;
      _purchaseDate = item.purchaseDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _quantityController.dispose();
    _serialController.dispose();
    _valueController.dispose();
    _locationController.dispose();
    _assignedToController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);
    final formState = ref.watch(inventoryItemFormNotifierProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.sac.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.sac.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing ? 'Editar Artículo' : 'Nuevo Artículo',
                  style:
                      Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 20,
                    color: context.sac.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name (required)
                    _SectionLabel('Nombre del artículo *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'Ej: Tienda de campaña, Uniforme, etc.',
                        context: context,
                      ),
                      maxLength: 120,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'El nombre es requerido'
                          : null,
                    ),

                    const SizedBox(height: 14),

                    // Category (required)
                    _SectionLabel('Categoría *'),
                    const SizedBox(height: 6),
                    categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'No se pudieron cargar las categorías',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref.invalidate(
                                inventoryCategoriesProvider),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                      data: (cats) {
                        // Attempt to match existing category from the loaded list
                        InventoryCategory? dropdownValue;
                        if (_selectedCategory != null) {
                          try {
                            dropdownValue = cats.firstWhere(
                                (c) => c.id == _selectedCategory!.id);
                          } catch (_) {
                            dropdownValue = null;
                          }
                        }

                        return DropdownButtonFormField<InventoryCategory>(
                          // ignore: deprecated_member_use
                          value: dropdownValue,
                          decoration: _inputDecoration(
                            hint: 'Selecciona una categoría',
                            context: context,
                          ),
                          items: cats
                              .map((c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c.name),
                                  ))
                              .toList(),
                          onChanged: (c) =>
                              setState(() => _selectedCategory = c),
                          validator: (v) =>
                              v == null ? 'Selecciona una categoría' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 14),

                    // Condition (required)
                    _SectionLabel('Estado de conservación *'),
                    const SizedBox(height: 8),
                    _ConditionSelector(
                      selected: _condition,
                      onChanged: (c) => setState(() => _condition = c),
                    ),

                    const SizedBox(height: 14),

                    // Quantity (required)
                    _SectionLabel('Cantidad *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: _inputDecoration(
                        hint: '1',
                        context: context,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Ingresa la cantidad';
                        }
                        final parsed = int.tryParse(v);
                        if (parsed == null || parsed < 1) {
                          return 'Cantidad inválida';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // Description (optional)
                    _SectionLabel('Descripción (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'Describe el artículo...',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Serial number (optional)
                    _SectionLabel('Número de serie / código (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _serialController,
                      decoration: _inputDecoration(
                        hint: 'SN-000123',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Purchase date (optional)
                    _SectionLabel('Fecha de adquisición (opcional)'),
                    const SizedBox(height: 6),
                    _DatePickerField(
                      selectedDate: _purchaseDate,
                      onDateSelected: (d) => setState(() => _purchaseDate = d),
                      onClear: () => setState(() => _purchaseDate = null),
                    ),

                    const SizedBox(height: 14),

                    // Estimated value (optional)
                    _SectionLabel('Valor estimado (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _valueController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: _inputDecoration(
                        hint: '0.00',
                        prefix: '\$',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Location (optional)
                    _SectionLabel('Ubicación / almacén (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'Ej: Bodega principal, Oficina...',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Assigned to (optional)
                    _SectionLabel('Asignado a (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _assignedToController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hint: 'Nombre del responsable...',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Notes (optional)
                    _SectionLabel('Notas (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'Observaciones adicionales...',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error message
                    if (formState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          formState.errorMessage!,
                          style:
                              const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: formState.isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: formState.isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2)
                            : Text(
                                _isEditing
                                    ? 'Guardar cambios'
                                    : 'Registrar artículo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final clubId = await ref.read(inventoryClubIdProvider.future);
    if (clubId == null) return;

    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final value = _valueController.text.isNotEmpty
        ? double.tryParse(_valueController.text)
        : null;

    final success = await ref
        .read(inventoryItemFormNotifierProvider.notifier)
        .save(
          clubId: clubId,
          name: _nameController.text.trim(),
          categoryId: _selectedCategory!.id,
          quantity: quantity,
          condition: _condition,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          serialNumber: _serialController.text.trim().isEmpty
              ? null
              : _serialController.text.trim(),
          purchaseDate: _purchaseDate,
          estimatedValue: value,
          location: _locationController.text.trim().isEmpty
              ? null
              : _locationController.text.trim(),
          assignedTo: _assignedToController.text.trim().isEmpty
              ? null
              : _assignedToController.text.trim(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          existingId: _isEditing ? widget.existing!.id : null,
        );

    if (success && mounted) {
      ref.read(inventoryItemFormNotifierProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Artículo actualizado correctamente'
              : 'Artículo registrado correctamente'),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required BuildContext context,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      filled: true,
      fillColor: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color:
              Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}

// ── Condition selector ──────────────────────────────────────────────────────────

class _ConditionSelector extends StatelessWidget {
  final ItemCondition selected;
  final ValueChanged<ItemCondition> onChanged;

  const _ConditionSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: ItemCondition.values.map((c) {
        final isSelected = c == selected;
        final color = _conditionColor(c);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: c != ItemCondition.malo ? 8 : 0,
            ),
            child: GestureDetector(
              onTap: () => onChanged(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : Theme.of(context).dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.shortLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _conditionColor(ItemCondition c) {
    switch (c) {
      case ItemCondition.bueno:
        return AppColors.secondary;
      case ItemCondition.regular:
        return AppColors.accent;
      case ItemCondition.malo:
        return AppColors.error;
    }
  }
}

// ── Date picker field ───────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onClear;

  const _DatePickerField({
    required this.selectedDate,
    required this.onDateSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = selectedDate != null
        ? DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es').format(selectedDate!)
        : 'Seleccionar fecha';

    return InkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              size: 18,
              color: AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                formatted,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: selectedDate != null
                          ? null
                          : Theme.of(context).hintColor,
                    ),
              ),
            ),
            if (selectedDate != null)
              GestureDetector(
                onTap: onClear,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) onDateSelected(picked);
  }
}

// ── Section label ───────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}
