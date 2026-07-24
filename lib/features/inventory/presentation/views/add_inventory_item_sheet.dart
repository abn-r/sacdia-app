import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import 'package:sacdia_app/core/widgets/sac_text_field.dart';

import '../../../../core/widgets/evidence_staging/image_source_dialog.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
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

class _AddInventoryItemSheetState extends ConsumerState<AddInventoryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _serialController = TextEditingController();
  final _valueController = TextEditingController();
  final _locationController = TextEditingController();
  final _assignedToController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  ItemCondition _condition = ItemCondition.bueno;
  InventoryCategory? _selectedCategory;
  DateTime? _purchaseDate;
  final List<XFile> _newEvidenceFiles = [];
  String? _evidenceError;

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
                    SacTextField(
                      controller: _nameController,
                      hint: 'inventory.form.name_hint'.tr(),
                      textCapitalization: TextCapitalization.sentences,
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
                        final pickerValue = _selectedCategory != null &&
                                cats.any((c) => c.id == _selectedCategory!.id)
                            ? cats.firstWhere(
                                (c) => c.id == _selectedCategory!.id,
                              )
                            : null;

                        return FormField<InventoryCategory>(
                          key: ValueKey(pickerValue?.id ?? 'no-category'),
                          initialValue: pickerValue,
                          validator: (v) => v == null
                              ? 'inventory.form.category_required'.tr()
                              : null,
                          builder: (field) => _CategoryPickerField(
                            value: field.value,
                            hint: 'inventory.form.category_hint'.tr(),
                            errorText: field.errorText,
                            onTap: () async {
                              final picked = await _showCategoryPicker(
                                context,
                                categories: cats,
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

                    const SizedBox(height: 12),

                    // Quantity
                    _SectionLabel('inventory.form.quantity_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _quantityController,
                      hint: 'inventory.form.quantity_hint'.tr(),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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

                    // ── Section: Evidencias ───────────────────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedImage01,
                      title: 'inventory.form.section_evidence'.tr(),
                    ),
                    const SizedBox(height: 12),

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

                    const SizedBox(height: 16),

                    // ── Section: Descripción y referencia ──────────────────
                    _SectionHeader(
                      icon: HugeIcons.strokeRoundedNote01,
                      title: 'inventory.form.section_description'.tr(),
                    ),
                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.description_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _descController,
                      hint: 'inventory.form.description_hint'.tr(),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.serial_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _serialController,
                      hint: 'inventory.form.serial_hint'.tr(),
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
                      onDateSelected: (d) => setState(() => _purchaseDate = d),
                      onClear: () => setState(() => _purchaseDate = null),
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.estimated_value_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _valueController,
                      hint: 'inventory.form.value_hint'.tr(),
                      prefixText: '\$',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
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
                    SacTextField(
                      controller: _locationController,
                      hint: 'inventory.form.location_hint'.tr(),
                      textCapitalization: TextCapitalization.sentences,
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.assigned_to_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _assignedToController,
                      hint: 'inventory.form.assigned_to_hint'.tr(),
                      textCapitalization: TextCapitalization.words,
                    ),

                    const SizedBox(height: 12),

                    _SectionLabel('inventory.form.notes_label'.tr()),
                    const SizedBox(height: 6),
                    SacTextField(
                      controller: _notesController,
                      hint: 'inventory.form.notes_hint'.tr(),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
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
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSM,
                            ),
                          ),
                        ),
                        child: formState.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
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

    final existingEvidenceCount = widget.existing?.evidences.length ?? 0;
    final totalEvidenceCount = existingEvidenceCount + _newEvidenceFiles.length;
    if (!_isEditing && _newEvidenceFiles.isEmpty) {
      setState(() {
        _evidenceError = 'inventory.form.evidence_required'.tr();
      });
      return;
    }
    if (totalEvidenceCount > 3) {
      setState(() {
        _evidenceError = 'inventory.form.evidence_limit'.tr();
      });
      return;
    }

    final clubId = await ref.read(inventoryClubIdProvider.future);
    if (clubId == null) return;
    final instanceType = await ref.read(inventoryInstanceTypeProvider.future);

    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final value = _valueController.text.isNotEmpty
        ? double.tryParse(_valueController.text)
        : null;

    final success =
        await ref.read(inventoryItemFormNotifierProvider.notifier).save(
              clubId: clubId,
              instanceType: instanceType,
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

    if (!success || !mounted) return;

    final savedItem = ref.read(inventoryItemFormNotifierProvider).savedItem ??
        widget.existing;
    final itemId = savedItem?.id;
    if (itemId == null) return;

    if (_newEvidenceFiles.isNotEmpty) {
      final uploaded = await _uploadEvidenceFiles(itemId);
      if (!uploaded || !mounted) return;
    }

    if (mounted) {
      ref.read(inventoryItemFormNotifierProvider.notifier).reset();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'inventory.form.updated_success'.tr()
                : 'inventory.form.registered_success'.tr(),
          ),
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
      setState(() => _evidenceError = 'inventory.form.evidence_limit'.tr());
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
        _evidenceError = 'inventory.form.evidence_pick_error'.tr();
      });
    }
  }

  Future<bool> _uploadEvidenceFiles(int itemId) async {
    final notifier = ref.read(inventoryItemFormNotifierProvider.notifier);
    for (final file in _newEvidenceFiles) {
      final success = await notifier.uploadEvidence(
        itemId: itemId,
        filePath: file.path,
        fileName: file.name,
        mimeType: _mimeFor(file),
      );
      if (!success) {
        setState(() {
          _evidenceError =
              ref.read(inventoryItemFormNotifierProvider).errorMessage ??
                  'inventory.errors.upload_evidence'.tr();
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

// ── Section header ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final List<List<dynamic>> icon;
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
        Expanded(child: Divider(color: context.sac.border, thickness: 1)),
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

  const _ConditionSelector({required this.selected, required this.onChanged});

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
                    color: isSelected ? color : Theme.of(context).dividerColor,
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
                          color: isSelected ? color : context.sac.textSecondary,
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

// ── Category picker field ─────────────────────────────────────────────────────

class _CategoryPickerField extends StatelessWidget {
  final InventoryCategory? value;
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
                              fontWeight:
                                  hasValue ? FontWeight.w600 : FontWeight.w500,
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

Future<InventoryCategory?> _showCategoryPicker(
  BuildContext context, {
  required List<InventoryCategory> categories,
  InventoryCategory? selected,
}) {
  return showModalBottomSheet<InventoryCategory>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _CategoryPickerSheet(categories: categories, selected: selected),
  );
}

class _CategoryPickerSheet extends StatelessWidget {
  final List<InventoryCategory> categories;
  final InventoryCategory? selected;

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
                      'inventory.form.category_label'.tr(),
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
  final InventoryCategory category;
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
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
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

// ── Evidence picker ────────────────────────────────────────────────────────────

class _EvidencePicker extends StatelessWidget {
  final List<InventoryEvidence> existingEvidences;
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
          'inventory.form.evidence_hint'.tr(),
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
          'inventory.form.evidence_count'.tr(
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
            color: context.sac.surfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Center(
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedAdd01,
              size: 26,
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

  const _EvidenceTile.network(this.url)
      : file = null,
        onRemove = null;

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
        TextButton(onPressed: onRetry, child: Text('common.retry'.tr())),
      ],
    );
  }
}
