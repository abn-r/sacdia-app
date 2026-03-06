import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../domain/entities/member_insurance.dart';
import '../providers/seguros_providers.dart';

/// Bottom sheet para registrar o editar el seguro de un miembro.
///
/// - [preselectedMemberId]: ID del miembro (cuando se accede desde su tarjeta).
/// - [existingInsurance]: El registro existente cuando se edita.
class InsuranceFormSheet extends ConsumerStatefulWidget {
  final String? preselectedMemberId;
  final MemberInsurance? existingInsurance;

  const InsuranceFormSheet({
    super.key,
    this.preselectedMemberId,
    this.existingInsurance,
  });

  @override
  ConsumerState<InsuranceFormSheet> createState() =>
      _InsuranceFormSheetState();
}

class _InsuranceFormSheetState extends ConsumerState<InsuranceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _policyController = TextEditingController();
  final _providerController = TextEditingController();
  final _amountController = TextEditingController();

  InsuranceType _insuranceType = InsuranceType.generalActivities;
  DateTime? _startDate;
  DateTime? _endDate;

  bool get _isEditing => widget.existingInsurance != null;

  String get _memberId =>
      widget.preselectedMemberId ??
      widget.existingInsurance?.memberId ??
      '';

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final ins = widget.existingInsurance!;
      _policyController.text = ins.policyNumber ?? '';
      _providerController.text = ins.providerName ?? '';
      _amountController.text =
          ins.coverageAmount?.toStringAsFixed(2) ?? '';
      _insuranceType = ins.insuranceType ?? InsuranceType.generalActivities;
      _startDate = ins.startDate;
      _endDate = ins.endDate;
    }
  }

  @override
  void dispose() {
    _policyController.dispose();
    _providerController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(insuranceFormNotifierProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.sac.background,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
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
                  _isEditing
                      ? 'Editar seguro'
                      : 'Registrar seguro',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
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

          // Form body
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
                    // Insurance type selector
                    _SectionLabel('Tipo de seguro *'),
                    const SizedBox(height: 8),
                    _InsuranceTypeSelector(
                      selected: _insuranceType,
                      onChanged: (t) =>
                          setState(() => _insuranceType = t),
                    ),

                    const SizedBox(height: 16),

                    // Policy number
                    _SectionLabel('N. de póliza / folio (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _policyController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: _inputDecoration(
                        hint: 'POL-001234',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Provider / company
                    _SectionLabel('Aseguradora / empresa (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _providerController,
                      textCapitalization: TextCapitalization.words,
                      decoration: _inputDecoration(
                        hint: 'Nombre de la aseguradora...',
                        context: context,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Start date (required)
                    _SectionLabel('Fecha de inicio de cobertura *'),
                    const SizedBox(height: 6),
                    _DatePickerField(
                      selectedDate: _startDate,
                      placeholder: 'Seleccionar fecha de inicio',
                      onDateSelected: (d) =>
                          setState(() => _startDate = d),
                      onClear: () => setState(() => _startDate = null),
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    ),

                    const SizedBox(height: 14),

                    // End date (required)
                    _SectionLabel('Fecha de fin de cobertura *'),
                    const SizedBox(height: 6),
                    _DatePickerField(
                      selectedDate: _endDate,
                      placeholder: 'Seleccionar fecha de vencimiento',
                      onDateSelected: (d) =>
                          setState(() => _endDate = d),
                      onClear: () => setState(() => _endDate = null),
                      firstDate: _startDate ?? DateTime(2000),
                      lastDate: DateTime(2100),
                    ),

                    const SizedBox(height: 14),

                    // Coverage amount
                    _SectionLabel('Monto de cobertura / prima (opcional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
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

                    // Evidence file upload
                    _SectionLabel(
                        'Comprobante de pago (imagen o PDF)${!_isEditing ? ' *' : ' (opcional)'}'),
                    const SizedBox(height: 6),
                    _EvidenceUploader(
                      currentFile: ref
                          .watch(insuranceFormNotifierProvider)
                          .selectedFile,
                      existingFileUrl: _isEditing
                          ? widget.existingInsurance?.evidenceFileUrl
                          : null,
                      existingFileName: _isEditing
                          ? widget.existingInsurance?.evidenceFileName
                          : null,
                      onFileSelected: (file) {
                        ref
                            .read(insuranceFormNotifierProvider.notifier)
                            .setFile(file);
                      },
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
                        onPressed:
                            formState.isLoading ? null : _submit,
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
                                    : 'Registrar seguro',
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
    if (!_formKey.currentState!.validate()) return;

    // Validate required dates
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona la fecha de inicio de cobertura')),
      );
      return;
    }

    if (_endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Selecciona la fecha de fin de cobertura')),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'La fecha de fin debe ser posterior a la de inicio'),
        ),
      );
      return;
    }

    // Validate evidence for new records
    final selectedFile =
        ref.read(insuranceFormNotifierProvider).selectedFile;
    if (!_isEditing && selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Adjunta el comprobante de pago')),
      );
      return;
    }

    if (_memberId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo determinar el miembro')),
      );
      return;
    }

    final amount = _amountController.text.isNotEmpty
        ? double.tryParse(_amountController.text)
        : null;

    final success = await ref
        .read(insuranceFormNotifierProvider.notifier)
        .save(
          memberId: _memberId,
          insuranceType: _insuranceType,
          startDate: _startDate!,
          endDate: _endDate!,
          policyNumber: _policyController.text.trim().isEmpty
              ? null
              : _policyController.text.trim(),
          providerName: _providerController.text.trim().isEmpty
              ? null
              : _providerController.text.trim(),
          coverageAmount: amount,
          existingInsuranceId:
              _isEditing ? widget.existingInsurance!.insuranceId : null,
        );

    if (success && mounted) {
      ref.read(insuranceFormNotifierProvider.notifier).reset();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing
              ? 'Seguro actualizado correctamente'
              : 'Seguro registrado correctamente'),
          backgroundColor: AppColors.secondary,
        ),
      );
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
        borderSide:
            const BorderSide(color: AppColors.primary, width: 2),
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

// ── Insurance type selector ───────────────────────────────────────────────────

class _InsuranceTypeSelector extends StatelessWidget {
  final InsuranceType selected;
  final ValueChanged<InsuranceType> onChanged;

  const _InsuranceTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: InsuranceType.values.map((t) {
        final isSelected = t == selected;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => onChanged(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySurface
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).dividerColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Theme.of(context).dividerColor,
                        width: isSelected ? 5 : 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    t.label,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.primaryDark
                              : null,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date picker field ─────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  final DateTime? selectedDate;
  final String placeholder;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onClear;
  final DateTime firstDate;
  final DateTime lastDate;

  const _DatePickerField({
    required this.selectedDate,
    required this.placeholder,
    required this.onDateSelected,
    required this.onClear,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = selectedDate != null
        ? DateFormat('dd \'de\' MMMM \'de\' yyyy', 'es')
            .format(selectedDate!)
        : placeholder;

    return InkWell(
      onTap: () => _pickDate(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context)
                .dividerColor
                .withValues(alpha: 0.4),
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
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
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
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) onDateSelected(picked);
  }
}

// ── Evidence uploader ─────────────────────────────────────────────────────────

class _EvidenceUploader extends StatelessWidget {
  final XFile? currentFile;
  final String? existingFileUrl;
  final String? existingFileName;
  final ValueChanged<XFile?> onFileSelected;

  const _EvidenceUploader({
    required this.currentFile,
    required this.onFileSelected,
    this.existingFileUrl,
    this.existingFileName,
  });

  @override
  Widget build(BuildContext context) {
    if (currentFile != null) {
      return _SelectedFileTile(
        file: currentFile!,
        onRemove: () => onFileSelected(null),
      );
    }

    if (existingFileUrl != null && existingFileUrl!.isNotEmpty) {
      return _ExistingFileTile(
        fileName: existingFileName ?? 'Comprobante actual',
        onReplace: () => _showPicker(context),
      );
    }

    return _PickerButton(onTap: () => _showPicker(context));
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilePickerSheet(
        onSelected: onFileSelected,
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PickerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: AppColors.primarySurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedUpload01,
              size: 32,
              color: AppColors.primary,
            ),
            const SizedBox(height: 8),
            Text(
              'Subir comprobante',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'JPG, PNG o PDF',
              style: TextStyle(
                color: AppColors.primary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedFileTile extends StatelessWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _SelectedFileTile({required this.file, required this.onRemove});

  bool get _isImage {
    final ext = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Preview or icon
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _isImage
                ? Image.file(
                    File(file.path),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _FileIconBox(),
                  )
                : _FileIconBox(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.secondaryDark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Archivo seleccionado',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryDark.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCancel01,
              size: 18,
              color: AppColors.secondaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _FileIconBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      color: AppColors.secondary.withValues(alpha: 0.15),
      child: Center(
        child: HugeIcon(
          icon: HugeIcons.strokeRoundedFiles01,
          size: 28,
          color: AppColors.secondaryDark,
        ),
      ),
    );
  }
}

class _ExistingFileTile extends StatelessWidget {
  final String fileName;
  final VoidCallback onReplace;

  const _ExistingFileTile({required this.fileName, required this.onReplace});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAttachment,
            size: 24,
            color: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Comprobante actual',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.primary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onReplace,
            child: const Text(
              'Reemplazar',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── File picker bottom sheet ──────────────────────────────────────────────────

class _FilePickerSheet extends StatelessWidget {
  final ValueChanged<XFile?> onSelected;

  const _FilePickerSheet({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text(
              'Seleccionar comprobante',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCamera01,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
            ),
            title: const Text(
              'Tomar foto',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Usar la cámara del dispositivo'),
            onTap: () async {
              Navigator.pop(context);
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: ImageSource.camera,
                imageQuality: 85,
              );
              onSelected(file);
            },
          ),
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  size: 22,
                  color: AppColors.secondary,
                ),
              ),
            ),
            title: const Text(
              'Elegir de la galería',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('JPG o PNG desde tu galería'),
            onTap: () async {
              Navigator.pop(context);
              final picker = ImagePicker();
              final file = await picker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 85,
              );
              onSelected(file);
            },
          ),
          ListTile(
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedFiles01,
                  size: 22,
                  color: AppColors.accentDark,
                ),
              ),
            ),
            title: const Text(
              'Seleccionar PDF',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Archivo PDF de tu dispositivo'),
            onTap: () async {
              Navigator.pop(context);
              final picker = ImagePicker();
              // image_picker no soporta PDF directamente.
              // En producción usar file_picker para PDFs.
              // Por ahora se selecciona desde galería como fallback.
              final file = await picker.pickImage(
                source: ImageSource.gallery,
              );
              onSelected(file);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

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
