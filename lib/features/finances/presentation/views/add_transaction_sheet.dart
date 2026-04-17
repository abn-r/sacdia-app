import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';

/// Bottom sheet para agregar o editar un movimiento financiero.
///
/// Recibe [existing] cuando se está editando un movimiento existente.
class AddTransactionSheet extends ConsumerStatefulWidget {
  final FinanceTransaction? existing;

  const AddTransactionSheet({super.key, this.existing});

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _type = TransactionType.income;
  FinanceCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.existing!;
      _type = t.type;
      _amountController.text = t.amount.truncateToDouble() == t.amount
          ? t.amount.toStringAsFixed(0)
          : t.amount.toStringAsFixed(2);
      _descController.text = t.description;
      _notesController.text = t.notes ?? '';
      _selectedDate = t.date;
      _selectedCategory = t.category;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(financeCategoriesProvider);
    final formState = ref.watch(transactionFormNotifierProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.sac.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
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
                  _isEditing ? 'Editar Movimiento' : 'Nuevo Movimiento',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Type toggle
                    _TypeToggle(
                      selected: _type,
                      onChanged: (t) => setState(() => _type = t),
                    ),

                    const SizedBox(height: 16),

                    // Amount
                    _SectionLabel('Monto'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}')),
                      ],
                      decoration: _inputDecoration(
                        hint: '0',
                        prefix: '\$',
                        context: context,
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Ingresa el monto';
                        }
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed <= 0) {
                          return 'Monto inválido';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Category
                    _SectionLabel('Categoría'),
                    const SizedBox(height: 6),
                    categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => Row(
                        children: [
                          const Text('Error al cargar categorías'),
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(financeCategoriesProvider),
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                      data: (cats) {
                        final filtered = cats.where((c) {
                          return _type.isIncome
                              ? c.appliesToIncome
                              : c.appliesToExpense;
                        }).toList();

                        final dropdownValue = _selectedCategory != null &&
                                filtered.any(
                                    (c) => c.id == _selectedCategory!.id)
                            ? filtered.firstWhere(
                                (c) => c.id == _selectedCategory!.id)
                            : null;

                        return DropdownButtonFormField<FinanceCategory>(
                          // ignore: deprecated_member_use
                          value: dropdownValue,
                          decoration: _inputDecoration(
                            hint: 'Selecciona una categoría',
                            context: context,
                          ),
                          items: filtered
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (c) =>
                              setState(() => _selectedCategory = c),
                          validator: (v) =>
                              v == null ? 'Selecciona una categoría' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Description
                    _SectionLabel('Concepto'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      decoration: _inputDecoration(
                        hint: 'Describe el movimiento',
                        context: context,
                      ),
                      maxLength: 200,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Ingresa el concepto'
                              : null,
                    ),

                    const SizedBox(height: 16),

                    // Date
                    _SectionLabel('Fecha'),
                    const SizedBox(height: 6),
                    _DatePickerField(
                      selectedDate: _selectedDate,
                      onDateSelected: (d) =>
                          setState(() => _selectedDate = d),
                    ),

                    const SizedBox(height: 16),

                    // Notes (optional)
                    _SectionLabel('Notas (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: _inputDecoration(
                        hint: 'Observaciones adicionales...',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Error
                    if (formState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          formState.errorMessage!,
                          style: const TextStyle(color: AppColors.error),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: formState.isLoading
                            ? null
                            : () => _submit(selectedMonth),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: formState.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? 'Guardar cambios'
                                    : 'Registrar movimiento',
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

  Future<void> _submit(SelectedMonth selectedMonth) async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final amount = double.parse(_amountController.text);
    final clubIdAsync = await ref.read(currentClubIdProvider.future);
    if (clubIdAsync == null) return;

    final success = await ref
        .read(transactionFormNotifierProvider.notifier)
        .save(
          clubId: clubIdAsync,
          categoryId: _selectedCategory!.id,
          amount: amount,
          description: _descController.text.trim(),
          date: _selectedDate,
          year: selectedMonth.year,
          month: selectedMonth.month,
          existingId: _isEditing ? widget.existing!.id : null,
        );

    if (success && mounted) {
      ref.read(transactionFormNotifierProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transacción guardada correctamente'),
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
      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}

// ── Type toggle ────────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TypeChip(
            label: 'Ingreso',
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: AppColors.secondary,
            isSelected: selected == TransactionType.income,
            onTap: () => onChanged(TransactionType.income),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeChip(
            label: 'Egreso',
            icon: HugeIcons.strokeRoundedArrowUp01,
            color: AppColors.error,
            isSelected: selected == TransactionType.expense,
            onTap: () => onChanged(TransactionType.expense),
          ),
        ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  final String label;
  final List<List<dynamic>> icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: icon,
              size: 18,
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? color
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Date picker field ──────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _DatePickerField({
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final formatted =
        DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es').format(selectedDate);

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
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
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
            Text(
              formatted,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
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
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) onDateSelected(picked);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

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
