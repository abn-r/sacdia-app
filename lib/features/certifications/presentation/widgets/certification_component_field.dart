import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../domain/entities/certification_requirement_component.dart';

/// Renderiza el campo de captura correspondiente al
/// [CertificationRequirementComponent.type] de un componente.
///
/// IMPORTANTE: esta UI decide exclusivamente por `component.type` — nunca
/// por el nombre/ID de la certificación ni del requisito. Nuevos tipos de
/// componente que el backend agregue en el futuro caen en el caso
/// `unknown`, que se muestra en modo solo-lectura sin romper la pantalla.
class CertificationComponentField extends StatelessWidget {
  final CertificationRequirementComponent component;
  final bool canEdit;

  /// TEXT_RESPONSE
  final ValueChanged<String>? onTextChanged;

  /// ATTESTATION
  final ValueChanged<bool>? onAttestationChanged;

  /// LINKED_HONOR — texto libre con el ID del honor aprobado del usuario
  /// (ver limitación documentada: no hay selector con catálogo integrado).
  final ValueChanged<int?>? onLinkedHonorChanged;

  /// LINKED_ACTIVITY — ídem, ID de actividad como texto libre.
  final ValueChanged<int?>? onLinkedActivityChanged;

  /// FILE_EVIDENCE
  final Future<void> Function(
    XFile file,
    String mimeType,
    void Function(double progress) onProgress,
  )? onUploadEvidence;
  final Future<void> Function(String fileId)? onDeleteEvidence;

  const CertificationComponentField({
    super.key,
    required this.component,
    required this.canEdit,
    this.onTextChanged,
    this.onAttestationChanged,
    this.onLinkedHonorChanged,
    this.onLinkedActivityChanged,
    this.onUploadEvidence,
    this.onDeleteEvidence,
  });

  @override
  Widget build(BuildContext context) {
    switch (component.type) {
      case CertificationComponentType.textResponse:
        return _TextResponseField(
          component: component,
          canEdit: canEdit,
          onChanged: onTextChanged,
        );
      case CertificationComponentType.attestation:
        return _AttestationField(
          component: component,
          canEdit: canEdit,
          onChanged: onAttestationChanged,
        );
      case CertificationComponentType.linkedHonor:
        return _LinkedIdField(
          component: component,
          canEdit: canEdit,
          initialValue: component.response?.linkedUserHonorId,
          label: 'certifications.requirement_detail.linked_honor_hint'.tr(),
          onChanged: onLinkedHonorChanged,
        );
      case CertificationComponentType.linkedActivity:
        return _LinkedIdField(
          component: component,
          canEdit: canEdit,
          initialValue: component.response?.linkedActivityId,
          label: 'certifications.requirement_detail.linked_activity_hint'.tr(),
          onChanged: onLinkedActivityChanged,
        );
      case CertificationComponentType.fileEvidence:
        return _FileEvidenceField(
          component: component,
          canEdit: canEdit,
          onUpload: onUploadEvidence,
          onDelete: onDeleteEvidence,
        );
      case CertificationComponentType.autoValidation:
        return _AutoValidationField(component: component);
      case CertificationComponentType.unknown:
        return _UnknownComponentField(component: component);
    }
  }
}

// ── Shared header ────────────────────────────────────────────────────────────

class _ComponentCard extends StatelessWidget {
  final CertificationRequirementComponent component;
  final Widget child;

  const _ComponentCard({required this.component, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  component.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                    height: 1.3,
                  ),
                ),
              ),
              if (component.required) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.errorLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'certifications.requirement_detail.required_badge'.tr(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.errorDark,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// ── TEXT_RESPONSE ────────────────────────────────────────────────────────────

class _TextResponseField extends StatefulWidget {
  final CertificationRequirementComponent component;
  final bool canEdit;
  final ValueChanged<String>? onChanged;

  const _TextResponseField({
    required this.component,
    required this.canEdit,
    this.onChanged,
  });

  @override
  State<_TextResponseField> createState() => _TextResponseFieldState();
}

class _TextResponseFieldState extends State<_TextResponseField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.component.response?.textValue ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ComponentCard(
      component: widget.component,
      child: TextField(
        controller: _controller,
        enabled: widget.canEdit,
        minLines: 3,
        maxLines: 6,
        maxLength: 4000,
        decoration: InputDecoration(
          hintText: 'certifications.requirement_detail.text_response_hint'.tr(),
          isDense: true,
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}

// ── ATTESTATION ───────────────────────────────────────────────────────────────

class _AttestationField extends StatelessWidget {
  final CertificationRequirementComponent component;
  final bool canEdit;
  final ValueChanged<bool>? onChanged;

  const _AttestationField({
    required this.component,
    required this.canEdit,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final confirmed = component.response?.attestationConfirmed ?? false;
    final c = context.sac;
    return _ComponentCard(
      component: component,
      child: InkWell(
        onTap: canEdit ? () => onChanged?.call(!confirmed) : null,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Checkbox(
                value: confirmed,
                onChanged:
                    canEdit ? (value) => onChanged?.call(value ?? false) : null,
              ),
              Expanded(
                child: Text(
                  'certifications.requirement_detail.attestation_label'.tr(),
                  style: TextStyle(fontSize: 13, color: c.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── LINKED_HONOR / LINKED_ACTIVITY ─────────────────────────────────────────

class _LinkedIdField extends StatefulWidget {
  final CertificationRequirementComponent component;
  final bool canEdit;
  final int? initialValue;
  final String label;
  final ValueChanged<int?>? onChanged;

  const _LinkedIdField({
    required this.component,
    required this.canEdit,
    required this.initialValue,
    required this.label,
    this.onChanged,
  });

  @override
  State<_LinkedIdField> createState() => _LinkedIdFieldState();
}

class _LinkedIdFieldState extends State<_LinkedIdField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialValue?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _ComponentCard(
      component: widget.component,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            enabled: widget.canEdit,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(isDense: true),
            onChanged: (value) =>
                widget.onChanged?.call(int.tryParse(value.trim())),
          ),
          const SizedBox(height: 6),
          Text(
            widget.label,
            style: TextStyle(fontSize: 11.5, color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ── FILE_EVIDENCE ─────────────────────────────────────────────────────────────

/// El backend no expone la lista de evidencias ya subidas por componente en
/// `getRequirement` — solo confirma la subida en el momento en que ocurre.
/// Por eso este campo siempre arranca sin archivos "existentes"; los
/// archivos subidos en la sesión actual sí se muestran mientras la pantalla
/// permanece abierta (ver limitación documentada en el reporte de Fase 5).
class _FileEvidenceField extends StatelessWidget {
  final CertificationRequirementComponent component;
  final bool canEdit;
  final Future<void> Function(
    XFile file,
    String mimeType,
    void Function(double progress) onProgress,
  )? onUpload;
  final Future<void> Function(String fileId)? onDelete;

  const _FileEvidenceField({
    required this.component,
    required this.canEdit,
    this.onUpload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _ComponentCard(
      component: component,
      // embeddedMode integra el manager en el scroll de la pantalla
      // contenedora en vez de reservar su propio Expanded/scroll interno.
      child: EvidenceStagingManager(
        embeddedMode: true,
        showActionBar: canEdit,
        canModify: canEdit,
        maxFiles: 3,
        existingFiles: const [],
        fileNameBuilder: (originalName, index) => originalName,
        onUpload: (xFile, mimeType, onProgress) async {
          await onUpload?.call(xFile, mimeType, onProgress);
        },
        onDeleteRemote: (fileId) async {
          await onDelete?.call(fileId);
        },
        onSubmit: () async {},
      ),
    );
  }
}

// ── AUTO_VALIDATION ──────────────────────────────────────────────────────────

class _AutoValidationField extends StatelessWidget {
  final CertificationRequirementComponent component;

  const _AutoValidationField({required this.component});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _ComponentCard(
      component: component,
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedCheckmarkCircle02,
            size: 18,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'certifications.requirement_detail.auto_validation_hint'.tr(),
              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── UNKNOWN ───────────────────────────────────────────────────────────────────

class _UnknownComponentField extends StatelessWidget {
  final CertificationRequirementComponent component;

  const _UnknownComponentField({required this.component});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _ComponentCard(
      component: component,
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            size: 16,
            color: c.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'certifications.requirement_detail.unknown_component_hint'.tr(),
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
