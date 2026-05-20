import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';

import '../../domain/entities/certificate_import_item.dart';

class CertificateImportItemEditorSheet extends StatefulWidget {
  const CertificateImportItemEditorSheet({
    super.key,
    required this.item,
    required this.onSave,
  });

  final CertificateImportItem item;
  final Future<void> Function(CertificateImportItem item) onSave;

  @override
  State<CertificateImportItemEditorSheet> createState() =>
      _CertificateImportItemEditorSheetState();
}

class _CertificateImportItemEditorSheetState
    extends State<CertificateImportItemEditorSheet> {
  late CertificateImportItemType _type;
  late final TextEditingController _nameController;
  late final TextEditingController _catalogController;
  late final TextEditingController _dateController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.item.type == CertificateImportItemType.unknown
        ? CertificateImportItemType.honor
        : widget.item.type;
    _nameController =
        TextEditingController(text: widget.item.detectedName ?? '');
    _catalogController = TextEditingController(
      text: '${widget.item.honorId ?? widget.item.classId ?? ''}',
    );
    final date = widget.item.completedAt ?? widget.item.detectedDate;
    _dateController = TextEditingController(
      text: date == null
          ? ''
          : '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _catalogController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 18,
          right: 18,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Corregir fila',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: SacButton(
                      text: 'Honor',
                      variant: _type == CertificateImportItemType.honor
                          ? SacButtonVariant.primary
                          : SacButtonVariant.outline,
                      onPressed: () => setState(
                          () => _type = CertificateImportItemType.honor),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SacButton(
                      text: 'Clase',
                      variant: _type == CertificateImportItemType.clazz
                          ? SacButtonVariant.primary
                          : SacButtonVariant.outline,
                      onPressed: () => setState(
                          () => _type = CertificateImportItemType.clazz),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Nombre detectado',
                controller: _nameController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'ID catálogo',
                controller: _catalogController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              _Field(
                label: 'Fecha completada',
                controller: _dateController,
                keyboardType: TextInputType.datetime,
                hint: 'AAAA-MM-DD',
              ),
              const SizedBox(height: 18),
              SacButton.primary(
                text: 'Guardar corrección',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final catalogId = int.tryParse(_catalogController.text.trim());
    final completedAt = DateTime.tryParse(_dateController.text.trim());
    final updated = CertificateImportItem(
      id: widget.item.id,
      batchId: widget.item.batchId,
      type: _type,
      honorId: _type == CertificateImportItemType.honor ? catalogId : null,
      classId: _type == CertificateImportItemType.clazz ? catalogId : null,
      detectedName: _nameController.text.trim(),
      detectedDate: widget.item.detectedDate,
      completedAt: completedAt,
      ocrConfidence: widget.item.ocrConfidence,
      fieldConfidence: widget.item.fieldConfidence,
      status: _isComplete(_type, catalogId, completedAt, _nameController.text)
          ? CertificateImportItemStatus.ready
          : CertificateImportItemStatus.needsReview,
      rejectionReason: widget.item.rejectionReason,
      appliedEntityType: widget.item.appliedEntityType,
      appliedEntityId: widget.item.appliedEntityId,
    );

    setState(() => _saving = true);
    await widget.onSave(updated);
    if (mounted) Navigator.of(context).pop();
  }

  bool _isComplete(
    CertificateImportItemType type,
    int? catalogId,
    DateTime? completedAt,
    String name,
  ) {
    return type != CertificateImportItemType.unknown &&
        catalogId != null &&
        completedAt != null &&
        name.trim().isNotEmpty;
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.textInputAction,
    this.hint,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: c.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.border),
        ),
      ),
    );
  }
}
