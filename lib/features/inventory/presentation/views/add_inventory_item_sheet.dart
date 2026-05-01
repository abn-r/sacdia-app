import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../domain/entities/inventory_category.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';

/// Bottom sheet para agregar o editar un ítem de inventario.
///
/// Recibe [existing] cuando se edita un ítem existente.
/// Campos agrupados visualmente por secciones con separadores.
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
    final c = context.sac;

    return Container(
      decoration: BoxDecoration(
        color: c.background,
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
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isEditing
                        ? 'inventory.form.title_edit'.tr()
                        : 'inventory.form.title_new'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 20,
                    color: c.textSecondary,
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
                    // ── Section: Información básica ────────────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedPackage,
                      title: 'inventory.form.section_basic_info'.tr(),
                    ),
                    const SizedBox(height: 12),

                    // Name
                    _SectionLabel('inventory.form.name_label'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'inventory.form.name_hint'.tr(),
                        context: context,
                      ),
                      maxLength: 120,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'inventory.form.name_required'.tr()
                          : null,
                    ),

                    const SizedBox(height: 12),

                    // Category
                    _SectionLabel('inventory.form.category_label'.tr()),
                    const SizedBox(height: 6),
                    categoriesAsync.when(
                      loading: () => const _CategorySkeleton(),
                      error: (_, __) => _CategoryError(
                        onRetry: () =>
                            ref.invalidate(inventoryCategoriesProvider),
                      ),
                      data: (cats) {
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
                            hint: 'inventory.form.category_hint'.tr(),
                            context: context,
                          ),
                          items: cats
                              .map((cat) => DropdownMenuItem(
                                    value: cat,
                                    child: Text(cat.name),
                                  ))
                              .toList(),
                          onChanged: (cat) =>
                              setState(() => _selectedCategory = cat),
                          validator: (v) =>
                              v == null ? 'inventory.form.category_required'.tr() : null,
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    // Quantity
                    _SectionLabel('inventory.form.quantity_label'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: _inputDecoration(
                        hint: 'inventory.form.quantity_hint'.tr(),
                        context: context,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'inventory.form.quantity_required'.tr();
                        }
                        final parsed = int.tryParse(v);
                        if (parsed == null || parsed < 1) {
                          return 'inventory.form.quantity_invalid'.tr();
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Section: Estado ────────────────────────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      title: 'inventory.form.section_condition'.tr(),
                    ),
                    const SizedBox(height: 12),

                    _ConditionSelector(
                      selected: _condition,
                      onChanged: (cond) => setState(() => _condition = cond),
                    ),

                    const SizedBox(height: 16),

                    // ── Section: Descripción y referencia ──────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedNote01,
                      title: 'inventory.form.section_description'.tr(),
                    ),
                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.description_label'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'inventory.form.description_hint'.tr(),
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.serial_label'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _serialController,
                      decoration: _inputDecoration(
                        hint: 'inventory.form.serial_hint'.tr(),
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Section: Valor y fecha ─────────────────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedMoney01,
                      title: 'inventory.form.section_value'.tr(),
                    ),
                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.purchase_date_label'.tr()),
                    const SizedBox(height: 6),
                    _DatePickerField(
                      selectedDate: _purchaseDate,
                      onDateSelected: (d) =>
                          setState(() => _purchaseDate = d),
                      onClear: () => setState(() => _purchaseDate = null),
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.estimated_value_label'.tr()),
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
                        hint: 'inventory.form.value_hint'.tr(),
                        prefix: '\$',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Section: Ubicación y asignación ───────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedLocation01,
                      title: 'inventory.form.section_location'.tr(),
                    ),
                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.location_label'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _locationController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'inventory.form.location_hint'.tr(),
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.assigned_to_label'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _assignedToController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hint: 'inventory.form.assigned_to_hint'.tr(),
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.notes_label'.tr()),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: _inputDecoration(
                        hint: 'inventory.form.notes_hint'.tr(),
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error message
                    if (formState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            formState.errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
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
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSM),
                          ),
                        ),
                        child: formState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                _isEditing
                                    ? 'common.save'.tr()
                                    : 'inventory.form.register_button'.tr(),
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
              ? 'inventory.form.updated_success'.tr()
              : 'inventory.form.registered_success'.tr()),
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
      fillColor: context.sac.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: BorderSide(color: context.sac.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }
}

// ── Section header ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final HugeIconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: HugeIcon(icon: icon, size: 15, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: context.sac.text,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(color: context.sac.border, thickness: 1),
        ),
      ],
    );
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
            color: context.sac.textSecondary,
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
      children: ItemCondition.values.map((cond) {
        final isSelected = cond == selected;
        final color = _conditionColor(cond);
        final isLast = cond == ItemCondition.malo;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              onTap: () => onChanged(cond),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                  border: Border.all(
                    color:
                        isSelected ? color : Theme.of(context).dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1.04 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        cond.shortLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? color
                              : context.sac.textSecondary,
                        ),
                      ),
                    ],
                  ),
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
        ? DateFormat("dd 'de' MMMM 'de' yyyy", 'es').format(selectedDate!)
        : 'inventory.form.select_date'.tr();

    return InkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: context.sac.border),
        ),
        child: Row(
          children: [
            const HugeIcon(
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
                  color: context.sac.textSecondary,
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

// ── Category loading/error helpers ─────────────────────────────────────────────

class _CategorySkeleton extends StatelessWidget {
  const _CategorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: context.sac.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: context.sac.border),
      ),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.sac.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _CategoryError extends StatelessWidget {
  final VoidCallback onRetry;

  const _CategoryError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'inventory.form.categories_error'.tr(),
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('common.retry'.tr()),
        ),
      ],
    );
  }
}
