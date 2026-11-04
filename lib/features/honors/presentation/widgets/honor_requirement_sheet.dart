import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sacdia_app/core/errors/user_error_message.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/choice_group_header.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/requirement_tree_item.dart';

/// Sheet that edits ONE top-level requirement and everything under it.
///
/// It owns its edits (ticks and written answers). "Guardar" sends only the
/// nodes that changed with `bulkUpdate` and closes; closing with edits asks
/// for confirmation. Evidence uploads happen immediately and are not part of
/// the edits. With [enabled] false (under review) it is read-only.
class HonorRequirementSheet extends ConsumerStatefulWidget {
  const HonorRequirementSheet({
    super.key,
    required this.honorId,
    required this.requirement,
    required this.paintColor,
    required this.bandColor,
    required this.enabled,
  });

  final int honorId;
  final HonorRequirement requirement;

  /// Category paint (ticks, evidence actions).
  final Color paintColor;

  /// Darkened category color that holds white text (the save button).
  final Color bandColor;
  final bool enabled;

  static Future<void> show(
    BuildContext context, {
    required int honorId,
    required HonorRequirement requirement,
    required Color paintColor,
    required Color bandColor,
    required bool enabled,
  }) {
    return showSacSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // A drag would close the route without asking about unsaved edits.
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (_) => HonorRequirementSheet(
        honorId: honorId,
        requirement: requirement,
        paintColor: paintColor,
        bandColor: bandColor,
        enabled: enabled,
      ),
    );
  }

  @override
  ConsumerState<HonorRequirementSheet> createState() =>
      _HonorRequirementSheetState();
}

class _Snapshot {
  const _Snapshot(this.completed, this.notes, this.response);
  final bool completed;
  final String notes;
  final String response;
}

class _HonorRequirementSheetState extends ConsumerState<HonorRequirementSheet> {
  final Map<int, bool> _completed = {};
  final Map<int, TextEditingController> _responses = {};
  final Map<int, _Snapshot> _snapshot = {};

  bool _saving = false;
  int? _uploadingId;

  @override
  void initState() {
    super.initState();
    final progress = ref.read(userHonorProgressProvider(widget.honorId)).value;
    final byId = {
      for (final p in progress ?? const <UserHonorRequirementProgress>[])
        p.requirementId: p,
    };
    void init(HonorRequirement node) {
      final p = byId[node.id];
      final response = p?.textResponse ?? '';
      _completed[node.id] = p?.completed ?? false;
      _snapshot[node.id] = _Snapshot(
        p?.completed ?? false,
        p?.notes ?? '',
        response,
      );
      final controller = TextEditingController(text: response)
        ..addListener(_onEdited);
      _responses[node.id] = controller;
      node.children.forEach(init);
    }

    init(widget.requirement);
  }

  @override
  void dispose() {
    for (final c in _responses.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onEdited() {
    if (mounted) setState(() {});
  }

  bool get _isDirty => _changedIds().isNotEmpty;

  List<int> _changedIds() {
    return [
      for (final entry in _snapshot.entries)
        if (_completed[entry.key] != entry.value.completed ||
            (_responses[entry.key]?.text ?? '') != entry.value.response)
          entry.key,
    ];
  }

  void _toggle(int id) {
    if (!widget.enabled) return;
    setState(() => _completed[id] = !(_completed[id] ?? false));
  }

  Future<void> _confirmDiscard() async {
    final confirm = await SacDialog.show(
      context,
      title: 'honors.requirements.unsaved_title'.tr(),
      content: 'honors.requirements.unsaved_content'.tr(),
      cancelLabel: 'honors.requirements.unsaved_stay'.tr(),
      confirmLabel: 'honors.requirements.unsaved_exit'.tr(),
      confirmIsDestructive: true,
    );
    if (confirm == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _save() async {
    final changed = _changedIds();
    if (changed.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    final updates = [
      for (final id in changed)
        {
          'requirementId': id,
          'completed': _completed[id] ?? false,
          'notes': _snapshot[id]?.notes ?? '',
          'textResponse': _responses[id]?.text ?? '',
        },
    ];
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final notifier =
        ref.read(requirementProgressNotifierProvider(widget.honorId).notifier);
    final success = await notifier.bulkUpdate(updates);
    if (!mounted) return;
    if (success) {
      // Everything saved: closing needs no confirmation.
      for (final id in changed) {
        _snapshot[id] = _Snapshot(
          _completed[id] ?? false,
          _snapshot[id]?.notes ?? '',
          _responses[id]?.text ?? '',
        );
      }
      setState(() => _saving = false);
      navigator.pop();
      SacSnackBar.showMessenger(
        messenger,
        'honors.requirements.success_saved'.tr(),
        isSuccess: true,
        duration: const Duration(seconds: 2),
      );
    } else {
      setState(() => _saving = false);
      final error =
          ref.read(requirementProgressNotifierProvider(widget.honorId)).error;
      SacSnackBar.showMessenger(
        messenger,
        userErrorMessage(error),
        isError: true,
      );
    }
  }

  // ── Evidence ──────────────────────────────────────────────────────────────

  void _showEvidenceOptions(HonorRequirement requirement) {
    if (!widget.enabled) return;
    showSacSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLG)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SacSheetGrabber(),
            const SizedBox(height: 8),
            _PickerTile(
              icon: HugeIcons.strokeRoundedCamera01,
              color: ctx.sac.info,
              label: 'honors.requirements.pick_camera'.tr(),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(requirement, ImageSource.camera);
              },
            ),
            _PickerTile(
              icon: HugeIcons.strokeRoundedImage01,
              color: ctx.sac.success,
              label: 'honors.requirements.pick_gallery'.tr(),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(requirement, ImageSource.gallery);
              },
            ),
            _PickerTile(
              icon: HugeIcons.strokeRoundedPdf01,
              color: ctx.sac.error,
              label: 'honors.requirements.pick_pdf'.tr(),
              onTap: () {
                Navigator.pop(ctx);
                _pickPdf(requirement);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(
    HonorRequirement requirement,
    ImageSource source,
  ) async {
    final image = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;
    await _upload(requirement, File(image.path));
  }

  Future<void> _pickPdf(HonorRequirement requirement) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    final path = picked?.path;
    if (path == null) return;
    await _upload(requirement, File(path));
  }

  Future<void> _upload(HonorRequirement requirement, File file) async {
    final userId = ref.read(authNotifierProvider).value?.id;
    if (userId == null) {
      if (!mounted) return;
      SacSnackBar.show(context, 'honors.evidence.no_session'.tr(),
          isError: true);
      return;
    }
    setState(() => _uploadingId = requirement.id);
    final success = await ref
        .read(
            requirementEvidenceActionsNotifierProvider(widget.honorId).notifier)
        .uploadRequirementEvidence(
          userId: userId,
          honorId: widget.honorId,
          requirementId: requirement.id,
          file: file,
        );
    if (!mounted) return;
    setState(() => _uploadingId = null);
    SacSnackBar.show(
      context,
      success
          ? 'honors.requirements.requirement_evidence_success'.tr()
          : 'honors.requirements.requirement_evidence_error'.tr(),
      isSuccess: success,
      isError: !success,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final req = widget.requirement;
    final progress =
        ref.watch(userHonorProgressProvider(widget.honorId)).value ?? const [];
    final evidenceCount = {
      for (final p in progress) p.requirementId: p.evidences.length,
    };
    final label = (req.displayLabel != null && req.displayLabel!.isNotEmpty)
        ? req.displayLabel!
        : '${req.requirementNumber}';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope(
      canPop: !_isDirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmDiscard();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SacSheetHeader(
              title: 'honors.requirements.sheet_title'
                  .tr(namedArgs: {'number': label}),
              showClose: true,
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const ValueKey('requirement-sheet-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _node(req, 0, evidenceCount),
              ),
            ),
            if (widget.enabled)
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  border: Border(top: BorderSide(color: c.borderLight)),
                ),
                child: SacButton.primary(
                  text: 'honors.requirements.sheet_save'.tr(),
                  isLoading: _saving,
                  backgroundColor: widget.bandColor,
                  textColor: Colors.white,
                  onPressed: _saving ? null : _save,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _node(
    HonorRequirement node,
    int depth,
    Map<int, int> evidenceCount,
  ) {
    final c = context.sac;
    final hasChildren = node.children.isNotEmpty;
    // A plain parent is satisfied by its children; only show its own tick
    // when it asks for evidence (the backend then wants it ticked).
    final showCheck = !hasChildren || node.requiresEvidence;
    final done =
        node.children.where((child) => _completed[child.id] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RequirementTreeItem(
          key: ValueKey('sheet-req-${node.id}'),
          requirement: node,
          completed: _completed[node.id] ?? false,
          responseController: _responses[node.id],
          depth: 0,
          categoryColor: widget.paintColor,
          enabled: widget.enabled,
          showCheck: showCheck,
          initiallyExpanded: depth == 0,
          onToggle: () => _toggle(node.id),
          evidenceCount: evidenceCount[node.id] ?? 0,
          isUploadingEvidence: _uploadingId == node.id,
          onAddEvidence:
              node.requiresEvidence ? () => _showEvidenceOptions(node) : null,
        ),
        if (hasChildren) ...[
          if (node.isChoiceGroup && node.choiceMin != null)
            ChoiceGroupHeader(
              choiceMin: node.choiceMin!,
              totalChildren: node.children.length,
              completedChildren: done,
            ),
          Padding(
            padding: const EdgeInsets.only(left: 11, top: 4),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: c.border, width: 1.5),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < node.children.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: c.divider),
                      _node(node.children[i], depth + 1, evidenceCount),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final HugeIconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SacPressable(
      listenOnly: true,
      child: ListTile(
        enableFeedback: false,
        leading: HugeIcon(icon: icon, color: color),
        title: Text(label),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
      ),
    );
  }
}
