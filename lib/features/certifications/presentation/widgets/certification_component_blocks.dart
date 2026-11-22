import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/evidence_staging/evidence_staging_manager.dart';
import '../../../../core/widgets/evidence_staging/staged_file.dart';
import '../../../../core/widgets/sac_settings.dart';
import '../../../../core/widgets/sac_text_field.dart';
import '../../../honors/presentation/providers/honors_providers.dart';
import '../../domain/entities/certification_requirement_component.dart';
import '../providers/certification_requirement_providers.dart';
import 'certification_pick_sheets.dart';

/// Max length of a written answer (the backend's limit).
const int kCertificationAnswerMaxLength = 4000;

/// A file already uploaded, as the staging grid shows it: thumbnail through
/// the signed URL, never the technical name.
StagedFile stagedFileFromEvidence(CertificationComponentEvidence e) {
  return StagedFile(
    id: '${e.evidenceId}',
    name: e.originalFilename,
    type: e.isImage ? 'image' : 'pdf',
    status: StagedFileStatus.uploaded,
    remoteUrl: e.url,
    mimeType: e.mimeType,
    uploadedAt: e.confirmedAt,
  );
}

/// Small uppercase title of a block, like the eyebrow of a grouped section.
class CertificationBlockEyebrow extends StatelessWidget {
  const CertificationBlockEyebrow({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: context.sac.textTertiary,
        ),
      ),
    );
  }
}

/// The prompt and help text of a component, when it has them.
class _ComponentIntro extends StatelessWidget {
  const _ComponentIntro({required this.component, this.hideLabel = false});

  final CertificationRequirementComponent component;

  /// The label repeats the requirement text shown above.
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final label = hideLabel ? '' : component.label.trim();
    final help = component.instructions?.trim() ?? '';
    if (label.isEmpty && help.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                fontSize: SacFontSize.titleMedium,
                height: 1.4,
                color: c.text,
              ),
            ),
          if (help.isNotEmpty) ...[
            if (label.isNotEmpty) const SizedBox(height: 4),
            Text(
              help,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                height: 1.4,
                color: c.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── TEXT_RESPONSE ─────────────────────────────────────────────────────────────

/// «Tu respuesta»: a multiline field with its counter. What is typed is kept
/// on the phone as a local draft while writing (no «Guardar borrador»
/// button); it reaches the server when the requirement is sent.
class CertificationTextBlock extends StatefulWidget {
  const CertificationTextBlock({
    super.key,
    required this.component,
    required this.canEdit,
    required this.onChanged,
    this.requirementName = '',
  });

  final CertificationRequirementComponent component;
  final bool canEdit;
  final ValueChanged<String> onChanged;
  final String requirementName;

  @override
  State<CertificationTextBlock> createState() => _CertificationTextBlockState();
}

class _CertificationTextBlockState extends State<CertificationTextBlock> {
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
    final c = context.sac;
    final component = widget.component;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CertificationBlockEyebrow(
          title: 'certifications.req.answer_title'.tr(),
        ),
        _ComponentIntro(
          component: component,
          hideLabel: component.label.trim() == widget.requirementName.trim(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: widget.canEdit
              ? SacTextField(
                  key: const ValueKey('certification-answer-field'),
                  controller: _controller,
                  hint: 'certifications.req.answer_hint'.tr(),
                  maxLines: 6,
                  maxLength: kCertificationAnswerMaxLength,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: widget.onChanged,
                )
              : Container(
                  key: const ValueKey('certification-answer-readonly'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    border: Border.all(color: c.border),
                  ),
                  child: Text(
                    _controller.text,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      height: 1.45,
                      color: c.text,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ── FILE_EVIDENCE ─────────────────────────────────────────────────────────────

/// «Archivos · N de M»: the staging grid with its «Agregar» tile. The files
/// already uploaded come from the server (thumbnail through the signed URL).
/// The screen owns the single action; this block only holds the grid.
class CertificationFilesBlock extends StatelessWidget {
  const CertificationFilesBlock({
    super.key,
    required this.managerKey,
    required this.component,
    required this.canEdit,
    required this.isResend,
    required this.isLoading,
    required this.title,
    required this.onUpload,
    required this.onDelete,
    required this.onSubmit,
    required this.onLocalFilesChanged,
    required this.onActionStateChanged,
    this.requirementName = '',
  });

  final GlobalKey<EvidenceStagingManagerState> managerKey;
  final CertificationRequirementComponent component;
  final bool canEdit;
  final bool isResend;
  final bool isLoading;
  final String title;
  final String requirementName;
  final Future<void> Function(
    int componentId,
    XFile file,
    String mimeType,
    void Function(double progress) onProgress,
  ) onUpload;
  final Future<void> Function(String fileId) onDelete;

  /// Runs once the staged files are uploaded (or there were none).
  final Future<void> Function() onSubmit;
  final ValueChanged<bool> onLocalFilesChanged;
  final VoidCallback onActionStateChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        _ComponentIntro(
          component: component,
          hideLabel: component.label.trim() == requirementName.trim(),
        ),
        EvidenceStagingManager(
          key: managerKey,
          embeddedMode: true,
          showActionBar: false,
          existingFiles: [
            for (final e in component.evidences) stagedFileFromEvidence(e),
          ],
          maxFiles: component.maxFiles,
          isLoading: isLoading,
          canModify: canEdit,
          isResend: isResend,
          sectionTitle: title,
          fileNameBuilder: (originalName, index) => originalName,
          onUpload: (xFile, mimeType, onProgress) =>
              onUpload(component.componentId, xFile, mimeType, onProgress),
          onDeleteRemote: onDelete,
          onSubmit: onSubmit,
          onLocalFilesChanged: onLocalFilesChanged,
          onActionStateChanged: onActionStateChanged,
        ),
      ],
    );
  }
}

// ── LINKED_ACTIVITY ───────────────────────────────────────────────────────────

/// «Actividad»: the chosen activity as a row and, when it can be edited, the
/// «Elegir actividad» row that opens the list the server offers.
class CertificationActivityBlock extends ConsumerWidget {
  const CertificationActivityBlock({
    super.key,
    required this.component,
    required this.query,
    required this.canEdit,
    required this.selectedId,
    required this.onChanged,
    this.requirementName = '',
  });

  final CertificationRequirementComponent component;
  final CertificationActivityOptionsQuery query;
  final bool canEdit;
  final int? selectedId;
  final ValueChanged<int> onChanged;
  final String requirementName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = selectedId == null
        ? null
        : ref.watch(certificationActivityOptionsProvider(query)).value;
    final chosen = [
      for (final o in options ?? const [])
        if (o.activityId == selectedId) o,
    ].firstOrNull;

    Future<void> pick() async {
      final option = await showCertificationActivitySheet(
        context,
        query: query,
        selectedId: selectedId,
      );
      if (option != null) onChanged(option.activityId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CertificationBlockEyebrow(
          title: 'certifications.req.activity_title'.tr(),
        ),
        _ComponentIntro(
          component: component,
          hideLabel: component.label.trim() == requirementName.trim(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Card(
            children: [
              if (selectedId != null)
                CertificationPickRow(
                  key: const ValueKey('certification-activity-chosen'),
                  icon: HugeIcons.strokeRoundedCalendar03,
                  title: chosen?.name ??
                      'certifications.req.activity_unknown'
                          .tr(namedArgs: {'id': '$selectedId'}),
                  detail: chosen == null ? null : formatActivityDetail(chosen),
                  onTap: canEdit ? pick : null,
                ),
              if (canEdit && selectedId == null)
                CertificationPickRow(
                  key: const ValueKey('certification-activity-choose'),
                  icon: HugeIcons.strokeRoundedAdd01,
                  title: 'certifications.req.activity_choose'.tr(),
                  accent: true,
                  onTap: pick,
                ),
              if (!canEdit && selectedId == null)
                CertificationPickRow(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  title: 'certifications.req.activity_none'.tr(),
                  onTap: null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── LINKED_HONOR ──────────────────────────────────────────────────────────────

/// «Especialidad»: the same picker with the user's approved honors.
class CertificationHonorBlock extends ConsumerWidget {
  const CertificationHonorBlock({
    super.key,
    required this.component,
    required this.canEdit,
    required this.selectedId,
    required this.onChanged,
    this.requirementName = '',
  });

  final CertificationRequirementComponent component;
  final bool canEdit;
  final int? selectedId;
  final ValueChanged<int> onChanged;
  final String requirementName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final honors =
        selectedId == null ? null : ref.watch(userHonorsProvider).value;
    final chosen = [
      for (final h in honors ?? const [])
        if (h.id == selectedId) h,
    ].firstOrNull;

    Future<void> pick() async {
      final honor = await showCertificationHonorSheet(
        context,
        selectedId: selectedId,
      );
      if (honor != null) onChanged(honor.id);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CertificationBlockEyebrow(
          title: 'certifications.req.honor_title'.tr(),
        ),
        _ComponentIntro(
          component: component,
          hideLabel: component.label.trim() == requirementName.trim(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Card(
            children: [
              if (selectedId != null)
                CertificationPickRow(
                  key: const ValueKey('certification-honor-chosen'),
                  icon: HugeIcons.strokeRoundedAward01,
                  title: chosen?.honorName ??
                      'certifications.req.honor_unknown'
                          .tr(namedArgs: {'id': '$selectedId'}),
                  detail: chosen?.honorCategoryName,
                  onTap: canEdit ? pick : null,
                )
              else
                CertificationPickRow(
                  key: const ValueKey('certification-honor-choose'),
                  icon: canEdit
                      ? HugeIcons.strokeRoundedAdd01
                      : HugeIcons.strokeRoundedAward01,
                  title: canEdit
                      ? 'certifications.req.honor_choose'.tr()
                      : 'certifications.req.honor_none'.tr(),
                  accent: canEdit,
                  onTap: canEdit ? pick : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── ATTESTATION ───────────────────────────────────────────────────────────────

/// «Constancia»: one row with a switch, «Confirmo que cumplí con lo
/// solicitado».
class CertificationAttestationBlock extends StatelessWidget {
  const CertificationAttestationBlock({
    super.key,
    required this.component,
    required this.canEdit,
    required this.confirmed,
    required this.onChanged,
    this.requirementName = '',
  });

  final CertificationRequirementComponent component;
  final bool canEdit;
  final bool confirmed;
  final ValueChanged<bool> onChanged;
  final String requirementName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CertificationBlockEyebrow(
          title: 'certifications.req.attestation_title'.tr(),
        ),
        _ComponentIntro(
          component: component,
          hideLabel: component.label.trim() == requirementName.trim(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _Card(
            children: [
              SacSettingsSwitchTile(
                key: const ValueKey('certification-attestation-switch'),
                icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                title:
                    'certifications.requirement_detail.attestation_label'.tr(),
                value: confirmed,
                onChanged: canEdit ? onChanged : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── AUTO_VALIDATION / UNKNOWN ─────────────────────────────────────────────────

/// A component the person does not fill in: the system validates it, or the
/// app does not know its type yet.
class CertificationInfoBlock extends StatelessWidget {
  const CertificationInfoBlock({
    super.key,
    required this.component,
    this.requirementName = '',
  });

  final CertificationRequirementComponent component;
  final String requirementName;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final isAuto = component.type == CertificationComponentType.autoValidation;
    final text = isAuto
        ? 'certifications.requirement_detail.auto_validation_hint'.tr()
        : 'certifications.requirement_detail.unknown_component_hint'.tr();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ComponentIntro(
          component: component,
          hideLabel: component.label.trim() == requirementName.trim(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HugeIcon(
                icon: isAuto
                    ? HugeIcons.strokeRoundedCheckmarkCircle02
                    : HugeIcons.strokeRoundedInformationCircle,
                size: 18,
                color: c.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: SacFontSize.bodySmall,
                    height: 1.4,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The bordered card that holds the rows of a block.
class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        side: BorderSide(color: c.border),
      ),
      child: Column(children: children),
    );
  }
}
