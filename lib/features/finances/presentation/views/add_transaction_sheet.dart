import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/image_source_dialog.dart';
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
                  _isEditing
                      ? 'finances.add_transaction.edit_title'.tr()
                      : 'finances.add_transaction.new_title'.tr(),
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
                    _SectionLabel('finances.add_transaction.amount_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _amountController,
                      hint: 'finances.add_transaction.amount_hint'.tr(),
                      prefixText: '\$',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
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
                          TextButton(
                            onPressed: () =>
                                ref.invalidate(financeCategoriesProvider),
                            child: Text('common.retry'.tr()),
                          ),
                        ],
                      ),
                      data: (cats) {
                        final filtered = cats.where((c) {
                          return _type.isIncome
                              ? c.appliesToIncome
                              : c.appliesToExpense;
                        }).toList();

                        final dropdownValue =
                            _selectedCategory != null &&
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
                          builder: (field) => _CategoryPickerField(
                            value: field.value,
                            hint: 'finances.add_transaction.category_hint'.tr(),
                            errorText: field.errorText,
                            onTap: () async {
                              final picked = await _showCategoryPicker(
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
                    _EvidencePicker(
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
                                    ? 'finances.add_transaction.save_button'
                                          .tr()
                                    : 'finances.add_transaction.register_button'
                                          .tr(),
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context, true);
        }
        return;
      }
    }

    if (mounted) {
      ref.read(transactionFormNotifierProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('finances.add_transaction.save_success'.tr()),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
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

// ── Evidence picker ────────────────────────────────────────────────────────────

class _EvidencePicker extends StatelessWidget {
  final List<FinanceEvidence> existingEvidences;
  final List<XFile> newFiles;
  final String? errorText;
  final VoidCallback onAdd;
  final ValueChanged<XFile> onRemoveNew;

  const _EvidencePicker({
    required this.existingEvidences,
    required this.newFiles,
    required this.onAdd,
    required this.onRemoveNew,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final total = existingEvidences.length + newFiles.length;
    final canAdd = total < 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'finances.add_transaction.evidence_hint'.tr(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.sac.textSecondary),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ...existingEvidences.map(
              (evidence) => _EvidenceTile.network(evidence.url),
            ),
            ...newFiles.map(
              (file) =>
                  _EvidenceTile.file(file, onRemove: () => onRemoveNew(file)),
            ),
            if (canAdd) _EvidenceAddTile(onTap: onAdd),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'finances.add_transaction.evidence_count'.tr(
            namedArgs: {'count': total.toString()},
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.sac.textTertiary),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

class _EvidenceAddTile extends StatelessWidget {
  final VoidCallback onTap;

  const _EvidenceAddTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 28,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _EvidenceTile extends StatelessWidget {
  final String? url;
  final XFile? file;
  final VoidCallback? onRemove;

  const _EvidenceTile.network(this.url) : file = null, onRemove = null;

  const _EvidenceTile.file(this.file, {required this.onRemove}) : url = null;

  @override
  Widget build(BuildContext context) {
    final image = file != null
        ? Image.file(
            File(file!.path),
            fit: BoxFit.cover,
            cacheWidth: 276,
            cacheHeight: 276,
          )
        : Image.network(
            url!,
            fit: BoxFit.cover,
            cacheWidth: 276,
            cacheHeight: 276,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          SizedBox(width: 92, height: 92, child: image),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Category picker field ─────────────────────────────────────────────────────

class _CategoryPickerField extends StatelessWidget {
  final FinanceCategory? value;
  final String hint;
  final String? errorText;
  final VoidCallback onTap;

  const _CategoryPickerField({
    required this.value,
    required this.hint,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    final borderColor = errorText != null
        ? AppColors.error
        : Theme.of(context).dividerColor.withValues(alpha: 0.4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: hasValue ? value!.name : hint,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: errorText != null ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTag01,
                        size: 20,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hasValue ? value!.name : hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: hasValue
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: hasValue
                              ? context.sac.text
                              : context.sac.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedArrowDown01,
                      size: 20,
                      color: context.sac.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }
}

Future<FinanceCategory?> _showCategoryPicker(
  BuildContext context, {
  required List<FinanceCategory> categories,
  FinanceCategory? selected,
}) {
  return showModalBottomSheet<FinanceCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CategoryPickerSheet(categories: categories, selected: selected),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  final List<FinanceCategory> categories;
  final FinanceCategory? selected;

  const _CategoryPickerSheet({required this.categories, this.selected});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.64;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        decoration: BoxDecoration(
          color: context.sac.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.sac.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedTag01,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'finances.add_transaction.category_label'.tr(),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  12,
                  4,
                  12,
                  MediaQuery.of(context).padding.bottom + 12,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, index) {
                  final category = categories[index];
                  final isSelected = category.id == selected?.id;

                  return _CategoryPickerOption(
                    category: category,
                    isSelected: isSelected,
                    onTap: () => Navigator.of(context).pop(category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPickerOption extends StatelessWidget {
  final FinanceCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPickerOption({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColors.primary : context.sac.text;
    final background = isSelected
        ? AppColors.primary.withValues(alpha: 0.08)
        : Colors.transparent;

    return Semantics(
      button: true,
      selected: isSelected,
      label: category.name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.24)
                    : context.sac.borderLight,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primarySurface
                        : context.sac.surfaceVariant,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedTag01,
                    size: 20,
                    color: isSelected
                        ? AppColors.primary
                        : context.sac.textSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedTick02,
                    size: 20,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
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
            label: 'finances.add_transaction.income'.tr(),
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: AppColors.secondary,
            isSelected: selected == TransactionType.income,
            onTap: () => onChanged(TransactionType.income),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _TypeChip(
            label: 'finances.add_transaction.expense'.tr(),
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
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : Colors.transparent,
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
    final formatted = DateFormat(
      'dd \'de\' MMMM \'de\' yyyy',
      'es',
    ).format(selectedDate);

    return InkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
