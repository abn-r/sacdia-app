import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import 'package:sacdia_app/core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/image_source_dialog.dart';
import '../../domain/entities/finance_category.dart';
import '../../domain/entities/transaction.dart';
import '../providers/finances_providers.dart';
import '../widgets/transaction_category_picker.dart';
import '../widgets/transaction_evidence_picker.dart';
import '../theme/finance_tokens.dart';
import 'package:sacdia_app/core/widgets/sac_date_picker.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';

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
  final _imagePicker = ImagePicker();
  final List<XFile> _newEvidenceFiles = [];

  TransactionType _type = TransactionType.income;
  FinanceCategory? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  String? _evidenceError;

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
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppTheme.radiusXL)),
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
              borderRadius: BorderRadius.circular(AppTheme.radiusHairline),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isEditing
                      ? 'finances.add_transaction.edit_title'.tr()
                      : 'finances.add_transaction.new_title'.tr(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                SacPressable(
                  listenOnly: true,
                  child: IconButton(
                    enableFeedback: false,
                    tooltip: 'common.close'.tr(),
                    onPressed: () => Navigator.pop(context),
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 20,
                      color: context.sac.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    _SectionLabel('finances.add_transaction.amount_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _amountController,
                      hint: 'finances.add_transaction.amount_hint'.tr(),
                      prefixText: '\$',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      // The iOS decimal pad has no Done key: tapping outside is
                      // the only way to close it.
                      onTapOutside: (_) => FocusScope.of(context).unfocus(),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'finances.add_transaction.amount_required'
                              .tr();
                        }
                        final parsed = double.tryParse(v);
                        if (parsed == null || parsed <= 0) {
                          return 'finances.add_transaction.amount_invalid'.tr();
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Category
                    _SectionLabel(
                      'finances.add_transaction.category_label'.tr(),
                    ),
                    const SizedBox(height: 6),
                    categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, __) => Row(
                        children: [
                          Text('finances.add_transaction.category_error'.tr()),
                          SacPressable(
                            listenOnly: true,
                            child: SacButton.text(
                              text: 'common.retry'.tr(),
                              onPressed: () =>
                                  ref.invalidate(financeCategoriesProvider),
                            ),
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
                                  (c) => c.id == _selectedCategory!.id,
                                )
                            ? filtered.firstWhere(
                                (c) => c.id == _selectedCategory!.id,
                              )
                            : null;

                        return FormField<FinanceCategory>(
                          key: ValueKey(
                            '${_type.name}-${dropdownValue?.id ?? 'none'}',
                          ),
                          initialValue: dropdownValue,
                          validator: (v) => v == null
                              ? 'finances.add_transaction.category_required'
                                  .tr()
                              : null,
                          builder: (field) => TransactionCategoryPickerField(
                            value: field.value,
                            hint: 'finances.add_transaction.category_hint'.tr(),
                            errorText: field.errorText,
                            onTap: () async {
                              final picked =
                                  await showTransactionCategoryPicker(
                                context,
                                categories: filtered,
                                selected: field.value,
                              );
                              if (!mounted || picked == null) return;

                              field.didChange(picked);
                              setState(() => _selectedCategory = picked);
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Description
                    _SectionLabel(
                      'finances.add_transaction.description_label'.tr(),
                    ),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _descController,
                      hint: 'finances.add_transaction.description_hint'.tr(),
                      maxLength: 200,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'finances.add_transaction.description_required'.tr()
                          : null,
                    ),

                    const SizedBox(height: 16),

                    // Date
                    _SectionLabel('finances.add_transaction.date_label'.tr()),
                    const SizedBox(height: 6),
                    _DatePickerField(
                      selectedDate: _selectedDate,
                      onDateSelected: (d) => setState(() => _selectedDate = d),
                    ),

                    const SizedBox(height: 16),

                    // Notes (optional)
                    _SectionLabel('finances.add_transaction.notes_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _notesController,
                      hint: 'finances.add_transaction.notes_hint'.tr(),
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Evidence photos (optional)
                    _SectionLabel(
                      'finances.add_transaction.evidence_label'.tr(),
                    ),
                    const SizedBox(height: 6),
                    TransactionEvidencePicker(
                      existingEvidences: widget.existing?.evidences ?? const [],
                      newFiles: _newEvidenceFiles,
                      errorText: _evidenceError,
                      onAdd: _pickEvidence,
                      onRemoveNew: (file) => setState(() {
                        _newEvidenceFiles.remove(file);
                        _evidenceError = null;
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Error
                    if (formState.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          formState.errorMessage!,
                          style: TextStyle(color: context.sac.error),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    // Save button
                    SacButton.primary(
                      text: _isEditing
                          ? 'finances.add_transaction.save_button'.tr()
                          : 'finances.add_transaction.register_button'.tr(),
                      isLoading: formState.isLoading,
                      onPressed: formState.isLoading
                          ? null
                          : () => _submit(selectedMonth),
                      borderRadius: 14,
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

    final existingEvidenceCount = widget.existing?.evidences.length ?? 0;
    final totalEvidenceCount = existingEvidenceCount + _newEvidenceFiles.length;
    if (totalEvidenceCount > 3) {
      setState(() {
        _evidenceError = 'finances.add_transaction.evidence_limit'.tr();
      });
      return;
    }

    final amount = double.parse(_amountController.text);
    final clubIdAsync = await ref.read(currentClubIdProvider.future);
    if (clubIdAsync == null) return;

    final success =
        await ref.read(transactionFormNotifierProvider.notifier).save(
              clubId: clubIdAsync,
              categoryId: _selectedCategory!.id,
              amount: amount,
              description: _descController.text.trim(),
              date: _selectedDate,
              year: selectedMonth.year,
              month: selectedMonth.month,
              existingId: _isEditing ? widget.existing!.id : null,
            );

    if (!success || !mounted) return;

    final savedTransaction =
        ref.read(transactionFormNotifierProvider).savedTransaction ??
            widget.existing;
    final financeId = savedTransaction?.id;
    if (financeId == null) return;

    if (_newEvidenceFiles.isNotEmpty) {
      final uploaded = await _uploadEvidenceFiles(financeId);
      if (!uploaded || !mounted) {
        if (mounted) {
          final error =
              _evidenceError ?? 'finances.errors.upload_evidence'.tr();
          ref.read(transactionFormNotifierProvider.notifier).reset();
          SacSnackBar.show(context, error, isError: true);
          Navigator.pop(context, true);
        }
        return;
      }
    }

    if (mounted) {
      ref.read(transactionFormNotifierProvider.notifier).reset();
      SacSnackBar.show(context, 'finances.add_transaction.save_success'.tr(),
          isSuccess: true);
      Navigator.pop(context, true);
    }
  }

  Future<void> _pickEvidence() async {
    final existingEvidenceCount = widget.existing?.evidences.length ?? 0;
    final remaining = 3 - existingEvidenceCount - _newEvidenceFiles.length;
    if (remaining <= 0) {
      setState(() {
        _evidenceError = 'finances.add_transaction.evidence_limit'.tr();
      });
      return;
    }

    final source = await showImageSourceDialog(context);
    if (!mounted || source == null) return;

    try {
      final picked = <XFile>[];
      if (source == ImageSource.camera) {
        final image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
        );
        if (image != null) picked.add(image);
      } else {
        final images = await _imagePicker.pickMultiImage(
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 85,
        );
        picked.addAll(images.take(remaining));
      }

      if (picked.isEmpty || !mounted) return;
      setState(() {
        _newEvidenceFiles.addAll(picked.take(remaining));
        _evidenceError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _evidenceError = 'finances.add_transaction.evidence_pick_error'.tr();
      });
    }
  }

  Future<bool> _uploadEvidenceFiles(int financeId) async {
    final notifier = ref.read(transactionFormNotifierProvider.notifier);
    for (final file in _newEvidenceFiles) {
      final success = await notifier.uploadEvidence(
        financeId: financeId,
        filePath: file.path,
        fileName: file.name,
        mimeType: _mimeFor(file),
      );
      if (!success) {
        setState(() {
          _evidenceError =
              ref.read(transactionFormNotifierProvider).errorMessage ??
                  'finances.errors.upload_evidence'.tr();
        });
        return false;
      }
    }
    return true;
  }

  String _mimeFor(XFile file) {
    return file.mimeType ?? lookupMimeType(file.path) ?? 'image/jpeg';
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
            label: 'finances.add_transaction.income'.tr(),
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: FinanceTokens.incomeFill(context),
            isSelected: selected == TransactionType.income,
            onTap: () => onChanged(TransactionType.income),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeChip(
            label: 'finances.add_transaction.expense'.tr(),
            icon: HugeIcons.strokeRoundedArrowUp01,
            color: FinanceTokens.expenseFill(context),
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
          color:
              isSelected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
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
                fontSize: SacFontSize.titleSmall,
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
    final formatted = DateFormat.yMMMMd().format(selectedDate);

    return SacInkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              size: 18,
              color: SacAccent.of(context).color,
            ),
            const SizedBox(width: 10),
            Text(
              formatted,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showSacDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
