import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/image_source_dialog.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_date_picker.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_expansion_tile.dart';
import '../../../../core/widgets/sac_picker_field.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../materials/presentation/widgets/qty_stepper.dart';
import '../../domain/entities/inventory_category.dart';
import '../../domain/entities/inventory_item.dart';
import '../providers/inventory_providers.dart';
import '../widgets/inventory_form_parts.dart';

/// Opens the add/edit form. Resolves to true when the item was saved.
///
/// Drag-to-dismiss is off on purpose: closing (button, barrier, back) goes
/// through the sheet's own unsaved-changes confirmation.
Future<bool?> showInventoryItemForm(
  BuildContext context, {
  InventoryItem? existing,
}) {
  return showSacSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => AddInventoryItemSheet(existing: existing),
  );
}

/// Add / edit form of an inventory item, in the order of the warehouse:
/// photos, name, category, quantity, condition, then an optional "more
/// details" group. Save stays fixed at the bottom.
///
/// [existing] is set when editing.
class AddInventoryItemSheet extends ConsumerStatefulWidget {
  final InventoryItem? existing;

  const AddInventoryItemSheet({super.key, this.existing});

  @override
  ConsumerState<AddInventoryItemSheet> createState() =>
      _AddInventoryItemSheetState();
}

class _AddInventoryItemSheetState extends ConsumerState<AddInventoryItemSheet> {
  static const int _maxQuantity = 9999;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _serialController = TextEditingController();
  final _valueController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _imagePicker = ImagePicker();

  ItemCondition _condition = ItemCondition.bueno;
  InventoryCategory? _selectedCategory;
  DateTime? _purchaseDate;
  int _quantity = 1;
  final List<XFile> _newEvidenceFiles = [];
  String? _evidenceError;
  String? _categoryError;

  // Snapshot to tell whether the form has unsaved changes.
  late final String _initialName;
  late final String _initialSerial;
  late final String _initialValue;
  late final String _initialLocation;
  late final String _initialNotes;
  late final ItemCondition _initialCondition;
  late final int? _initialCategoryId;
  late final DateTime? _initialDate;
  late final int _initialQuantity;
  bool _wasDirty = false;

  bool get _isEditing => widget.existing != null;

  bool get _isDirty =>
      _nameController.text != _initialName ||
      _serialController.text != _initialSerial ||
      _valueController.text != _initialValue ||
      _locationController.text != _initialLocation ||
      _notesController.text != _initialNotes ||
      _condition != _initialCondition ||
      _selectedCategory?.id != _initialCategoryId ||
      _purchaseDate != _initialDate ||
      _quantity != _initialQuantity ||
      _newEvidenceFiles.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    if (item != null) {
      _nameController.text = item.name;
      _serialController.text = item.serialNumber ?? '';
      _valueController.text = item.estimatedValue?.toStringAsFixed(2) ?? '';
      _locationController.text = item.location ?? '';
      _notesController.text = item.notes ?? '';
      _condition = item.condition;
      _selectedCategory = item.category;
      _purchaseDate = item.purchaseDate;
      _quantity = item.quantity;
    }
    _initialName = _nameController.text;
    _initialSerial = _serialController.text;
    _initialValue = _valueController.text;
    _initialLocation = _locationController.text;
    _initialNotes = _notesController.text;
    _initialCondition = _condition;
    _initialCategoryId = _selectedCategory?.id;
    _initialDate = _purchaseDate;
    _initialQuantity = _quantity;

    for (final controller in [
      _nameController,
      _serialController,
      _valueController,
      _locationController,
      _notesController,
    ]) {
      controller.addListener(_syncDirty);
    }
  }

  /// Rebuild only when the form flips between clean and dirty, not on every
  /// keystroke (the PopScope below depends on it).
  void _syncDirty() {
    final dirty = _isDirty;
    if (dirty != _wasDirty && mounted) setState(() => _wasDirty = dirty);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serialController.dispose();
    _valueController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _hasMoreDetails =>
      _serialController.text.isNotEmpty ||
      _valueController.text.isNotEmpty ||
      _locationController.text.isNotEmpty ||
      _notesController.text.isNotEmpty ||
      _purchaseDate != null;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);
    final formState = ref.watch(inventoryItemFormNotifierProvider);
    final c = context.sac;
    _wasDirty = _isDirty;

    return PopScope(
      canPop: !_isDirty || formState.isLoading,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Container(
          decoration: BoxDecoration(
            color: c.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SacSheetHeader(
                title: _isEditing
                    ? 'inventory.form.title_edit'.tr()
                    : 'inventory.form.title_new'.tr(),
                showClose: true,
              ),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: _buildFields(context, categoriesAsync, formState),
                  ),
                ),
              ),
              _SaveBar(
                label: _isEditing
                    ? 'common.save'.tr()
                    : 'inventory.form.register_button'.tr(),
                errorMessage: formState.errorMessage,
                isLoading: formState.isLoading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFields(
    BuildContext context,
    AsyncValue<List<InventoryCategory>> categoriesAsync,
    InventoryItemFormState formState,
  ) {
    final c = context.sac;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InventoryPhotoSlots(
          existing: widget.existing?.evidences ?? const [],
          picked: _newEvidenceFiles,
          errorText: _evidenceError,
          onAdd: _pickEvidence,
          onRemove: (file) => setState(() {
            _newEvidenceFiles.remove(file);
            _evidenceError = null;
          }),
        ),
        const SizedBox(height: 20),
        SacTextField(
          controller: _nameController,
          label: 'inventory.form.name_label'.tr(),
          hint: 'inventory.form.name_hint'.tr(),
          textCapitalization: TextCapitalization.sentences,
          maxLength: 120,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'inventory.form.name_required'.tr()
              : null,
        ),
        const SizedBox(height: 16),
        categoriesAsync.when(
          loading: () => SacPickerField(
            label: 'inventory.form.category_label'.tr(),
            hint: 'inventory.form.category_hint'.tr(),
            icon: HugeIcons.strokeRoundedTag01,
            isLoading: true,
          ),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InventoryFieldLabel('inventory.form.category_label'.tr()),
              const SizedBox(height: 6),
              InventoryCategoriesError(
                error: error,
                onRetry: () => ref.invalidate(inventoryCategoriesProvider),
              ),
            ],
          ),
          data: (cats) => SacPickerField(
            label: 'inventory.form.category_label'.tr(),
            hint: 'inventory.form.category_hint'.tr(),
            icon: HugeIcons.strokeRoundedTag01,
            selectedName: _selectedCategory?.name,
            errorText: _categoryError,
            onTap: () => _pickCategory(cats),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: InventoryFieldLabel('inventory.form.quantity_label'.tr()),
            ),
            QtyStepper(
              value: _quantity,
              max: _maxQuantity,
              onChanged: (value) => setState(() => _quantity = value),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InventoryFieldLabel('inventory.form.section_condition'.tr()),
        const SizedBox(height: 8),
        InventoryConditionOptions(
          selected: _condition,
          onChanged: (value) => setState(() => _condition = value),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SacExpansionTile(
            initiallyExpanded: _isEditing && _hasMoreDetails,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              'inventory.form.more_details'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            subtitle: Text(
              'inventory.form.more_details_hint'.tr(),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.textSecondary,
              ),
            ),
            children: [
              SacTextField(
                controller: _locationController,
                label: 'inventory.form.location_label'.tr(),
                hint: 'inventory.form.location_hint'.tr(),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              SacTextField(
                controller: _valueController,
                label: 'inventory.form.estimated_value_label'.tr(),
                hint: 'inventory.form.value_hint'.tr(),
                prefixText: r'$',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
              const SizedBox(height: 12),
              SacTextField(
                controller: _serialController,
                label: 'inventory.form.serial_label'.tr(),
                hint: 'inventory.form.serial_hint'.tr(),
              ),
              const SizedBox(height: 12),
              InventoryFieldLabel('inventory.form.purchase_date_label'.tr()),
              const SizedBox(height: 6),
              InventoryDateField(
                value: _purchaseDate,
                onTap: _pickDate,
                onClear: () => setState(() => _purchaseDate = null),
              ),
              const SizedBox(height: 12),
              SacTextField(
                controller: _notesController,
                label: 'inventory.form.notes_label'.tr(),
                hint: 'inventory.form.notes_hint'.tr(),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDiscard() async {
    final discard = await SacDialog.show(
      context,
      title: 'inventory.form.discard_title'.tr(),
      content: 'inventory.form.discard_body'.tr(),
      confirmLabel: 'inventory.form.discard_confirm'.tr(),
      cancelLabel: 'inventory.form.keep_editing'.tr(),
      confirmIsDestructive: true,
    );
    // Navigator.pop skips the PopScope, so this closes for real.
    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> _pickCategory(List<InventoryCategory> cats) async {
    final picked = await showInventoryCategorySheet(
      context,
      categories: cats,
      selected: _selectedCategory,
    );
    if (!mounted || picked == null) return;
    setState(() {
      _selectedCategory = picked;
      _categoryError = null;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showSacDatePicker(
      context: context,
      initialDate: _purchaseDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) setState(() => _purchaseDate = picked);
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    final nameOk = form?.validate() ?? false;

    if (_selectedCategory == null) {
      setState(() => _categoryError = 'inventory.form.category_required'.tr());
    }

    final existingCount = widget.existing?.evidences.length ?? 0;
    if (!_isEditing && _newEvidenceFiles.isEmpty) {
      setState(() => _evidenceError = 'inventory.form.evidence_required'.tr());
      return;
    }
    if (existingCount + _newEvidenceFiles.length > kInventoryMaxPhotos) {
      setState(() => _evidenceError = 'inventory.form.evidence_limit'.tr());
      return;
    }
    if (!nameOk || _selectedCategory == null) return;

    final clubId = await ref.read(inventoryClubIdProvider.future);
    if (clubId == null) return;
    final instanceType = await ref.read(inventoryInstanceTypeProvider.future);

    String? textOrNull(TextEditingController controller) {
      final text = controller.text.trim();
      return text.isEmpty ? null : text;
    }

    final existing = widget.existing;
    final success =
        await ref.read(inventoryItemFormNotifierProvider.notifier).save(
              clubId: clubId,
              instanceType: instanceType,
              name: _nameController.text.trim(),
              categoryId: _selectedCategory!.id,
              quantity: _quantity,
              condition: _condition,
              // Not on the form anymore: keep what the item already has,
              // because a null in the PATCH clears the field.
              description: existing?.description,
              assignedTo: existing?.assignedTo,
              serialNumber: textOrNull(_serialController),
              purchaseDate: _purchaseDate,
              estimatedValue: _valueController.text.isNotEmpty
                  ? double.tryParse(_valueController.text)
                  : null,
              location: textOrNull(_locationController),
              notes: textOrNull(_notesController),
              existingId: existing?.id,
            );

    if (!success || !mounted) return;

    final itemId = ref.read(inventoryItemFormNotifierProvider).savedItem?.id ??
        existing?.id;
    if (itemId == null) return;

    if (_newEvidenceFiles.isNotEmpty) {
      final uploaded = await _uploadEvidenceFiles(itemId);
      if (!uploaded || !mounted) return;
    }

    ref.read(inventoryItemFormNotifierProvider.notifier).reset();
    SacSnackBar.show(
      context,
      _isEditing
          ? 'inventory.form.updated_success'.tr()
          : 'inventory.form.registered_success'.tr(),
      isSuccess: true,
    );
    Navigator.pop(context, true);
  }

  Future<void> _pickEvidence() async {
    final existingCount = widget.existing?.evidences.length ?? 0;
    final remaining =
        kInventoryMaxPhotos - existingCount - _newEvidenceFiles.length;
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
        mimeType: file.mimeType ?? lookupMimeType(file.path) ?? 'image/jpeg',
      );
      if (!success) {
        if (mounted) {
          setState(() {
            _evidenceError =
                ref.read(inventoryItemFormNotifierProvider).errorMessage ??
                    'inventory.errors.upload_evidence'.tr();
          });
        }
        return false;
      }
    }
    return true;
  }
}

/// Fixed bottom bar with the error (if any) and the save button.
class _SaveBar extends StatelessWidget {
  final String label;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onPressed;

  const _SaveBar({
    required this.label,
    required this.errorMessage,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: c.error,
                      fontSize: SacFontSize.bodyMedium,
                    ),
                  ),
                ),
              SacButton.primary(
                key: const ValueKey('inventory-form-save'),
                text: label,
                isLoading: isLoading,
                onPressed: isLoading ? null : onPressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
