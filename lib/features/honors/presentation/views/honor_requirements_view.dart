import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:image_picker/image_picker.dart';

import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_dialog.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/presentation/theme/honor_category_palette.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/choice_group_header.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/requirement_tree_item.dart';
import 'package:sacdia_app/core/widgets/sac_sheet.dart';

// ── Local state helpers ───────────────────────────────────────────────────────

/// Per-requirement mutable state owned by the view.
class _RequirementState {
  final bool completed;
  final String notes;
  final String textResponse;
  final bool childrenExpanded;

  const _RequirementState({
    required this.completed,
    required this.notes,
    required this.textResponse,
    this.childrenExpanded = true,
  });

  _RequirementState copyWith({
    bool? completed,
    String? notes,
    String? textResponse,
    bool? childrenExpanded,
  }) {
    return _RequirementState(
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      textResponse: textResponse ?? this.textResponse,
      childrenExpanded: childrenExpanded ?? this.childrenExpanded,
    );
  }
}

SacTopBar _requirementsTopBar(BuildContext context, String honorName) {
  return SacTopBar(
    title: honorName,
    subtitle: 'honors.requirements.header_subtitle'.tr(),
    onBack: () {
      HapticFeedback.lightImpact();
      Navigator.of(context).maybePop();
    },
  );
}

// ── View ──────────────────────────────────────────────────────────────────────

/// Hierarchical checklist view for an enrolled honor's requirements.
///
/// Top-level requirements are rendered with [RequirementTreeItem] at depth=0.
/// When a requirement has children ([HonorRequirement.hasSubItems] == true),
/// they are rendered inline below the parent as depth=1 items.
/// Choice groups show a [ChoiceGroupHeader] before their children.
///
/// Progress is saved via [RequirementProgressNotifier.bulkUpdate].
class HonorRequirementsView extends ConsumerStatefulWidget {
  final int honorId;
  final int userHonorId;
  final String honorName;

  const HonorRequirementsView({
    super.key,
    required this.honorId,
    required this.userHonorId,
    required this.honorName,
  });

  @override
  ConsumerState<HonorRequirementsView> createState() =>
      _HonorRequirementsViewState();
}

class _HonorRequirementsViewState extends ConsumerState<HonorRequirementsView> {
  /// Map from requirementId → local mutable state.
  final Map<int, _RequirementState> _localState = {};

  /// TextEditingControllers for notes, keyed by requirementId.
  final Map<int, TextEditingController> _notesControllers = {};

  /// TextEditingControllers for text responses, keyed by requirementId.
  final Map<int, TextEditingController> _responseControllers = {};

  /// Snapshot of state at last save — used for dirty detection.
  final Map<int, ({bool completed, String notes, String textResponse})>
      _savedSnapshot = {};

  bool _saving = false;
  int? _uploadingRequirementId;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final c in _notesControllers.values) {
      c.dispose();
    }
    for (final c in _responseControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Initialise local state from server data, once per provider load.
  /// Handles both top-level requirements and their nested children.
  void _initLocalState(
    List<HonorRequirement> requirements,
    List<UserHonorRequirementProgress> progressList,
  ) {
    if (_localState.isNotEmpty) return;

    final progressMap = <int, UserHonorRequirementProgress>{};
    for (final item in progressList) {
      progressMap[item.requirementId] = item;
    }

    void initReq(HonorRequirement req) {
      final p = progressMap[req.id];
      final completed = p?.completed ?? false;
      final notes = p?.notes ?? '';
      final textResponse = p?.textResponse ?? '';

      _localState[req.id] = _RequirementState(
        completed: completed,
        notes: notes,
        textResponse: textResponse,
        // Expand children by default so the checklist is immediately visible.
        childrenExpanded: true,
      );
      _notesControllers[req.id] = TextEditingController(text: notes);
      _responseControllers[req.id] = TextEditingController(text: textResponse);
      _savedSnapshot[req.id] = (
        completed: completed,
        notes: notes,
        textResponse: textResponse,
      );

      for (final child in req.children) {
        initReq(child);
      }
    }

    for (final req in requirements) {
      initReq(req);
    }
  }

  bool get _hasUnsavedChanges {
    for (final entry in _localState.entries) {
      final snap = _savedSnapshot[entry.key];
      if (snap == null) return true;
      if (entry.value.completed != snap.completed) return true;
      final currentNotes = _notesControllers[entry.key]?.text ?? '';
      if (currentNotes != snap.notes) return true;
      final currentResponse = _responseControllers[entry.key]?.text ?? '';
      if (currentResponse != snap.textResponse) return true;
    }
    return false;
  }

  /// Count all requirements including children (for the denominator).
  int _countTotal(List<HonorRequirement> requirements) {
    int count = 0;
    for (final req in requirements) {
      count++;
      count += req.children.length;
    }
    return count;
  }

  /// Count completed across all requirements including children.
  int _countCompletedAll(List<HonorRequirement> requirements) {
    int count = 0;
    void walk(HonorRequirement req) {
      if (_localState[req.id]?.completed == true) count++;
      for (final child in req.children) {
        walk(child);
      }
    }

    for (final req in requirements) {
      walk(req);
    }
    return count;
  }

  void _toggleRequirement(int requirementId) {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor == null || !userHonor.canSubmit) return;
    setState(() {
      final current = _localState[requirementId];
      if (current == null) return;
      _localState[requirementId] =
          current.copyWith(completed: !current.completed);
    });
  }

  void _toggleChildrenExpand(int requirementId) {
    setState(() {
      final current = _localState[requirementId];
      if (current == null) return;
      _localState[requirementId] = current.copyWith(
        childrenExpanded: !current.childrenExpanded,
      );
    });
  }

  /// Collect all requirement IDs recursively.
  List<int> _allRequirementIds(List<HonorRequirement> requirements) {
    final ids = <int>[];
    void walk(HonorRequirement req) {
      ids.add(req.id);
      for (final child in req.children) {
        walk(child);
      }
    }

    for (final req in requirements) {
      walk(req);
    }
    return ids;
  }

  Future<void> _saveChanges(List<HonorRequirement> requirements) async {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor == null || !userHonor.canSubmit) return;

    final honor = ref
        .read(allHonorsProvider)
        .valueOrNull
        ?.where((h) => h.id == widget.honorId)
        .firstOrNull;
    final categoryName = honor?.categoryName ??
        (honor?.categoryId != null
            ? ref.read(categoryByIdProvider(honor!.categoryId))?.name
            : null);
    final categoryColor = getCategoryColor(
      categoryId: honor?.categoryId,
      categoryName: categoryName,
    );

    setState(() => _saving = true);

    final allIds = _allRequirementIds(requirements);
    final updates = <Map<String, dynamic>>[];

    for (final id in allIds) {
      final s = _localState[id];
      if (s == null) continue;
      updates.add({
        'requirementId': id,
        'completed': s.completed,
        'notes': _notesControllers[id]?.text ?? s.notes,
        'textResponse': _responseControllers[id]?.text ?? s.textResponse,
      });
    }

    final success = await ref
        .read(requirementProgressNotifierProvider(widget.honorId).notifier)
        .bulkUpdate(updates);

    if (!mounted) return;

    setState(() => _saving = false);

    if (success) {
      for (final id in allIds) {
        final s = _localState[id];
        if (s == null) continue;
        _savedSnapshot[id] = (
          completed: s.completed,
          notes: _notesControllers[id]?.text ?? s.notes,
          textResponse: _responseControllers[id]?.text ?? s.textResponse,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('honors.requirements.success_saved'.tr()),
          backgroundColor: categoryColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showRequirementEvidenceOptions(HonorRequirement requirement) {
    final userHonor = ref.read(userHonorForHonorProvider(widget.honorId));
    if (userHonor == null || !userHonor.canSubmit) return;

    showSacSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.pendingColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedCamera01,
                color: AppColors.info,
              ),
              title: Text('honors.requirements.pick_camera'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _pickRequirementCamera(requirement);
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedImage01,
                color: AppColors.success,
              ),
              title: Text('honors.requirements.pick_gallery'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _pickRequirementGallery(requirement);
              },
            ),
            ListTile(
              leading: const HugeIcon(
                icon: HugeIcons.strokeRoundedPdf01,
                color: AppColors.error,
              ),
              title: Text('honors.requirements.pick_pdf'.tr()),
              onTap: () {
                Navigator.pop(ctx);
                _pickRequirementPdf(requirement);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRequirementCamera(HonorRequirement requirement) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;
    await _uploadRequirementEvidence(requirement, File(image.path));
  }

  Future<void> _pickRequirementGallery(HonorRequirement requirement) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (image == null) return;
    await _uploadRequirementEvidence(requirement, File(image.path));
  }

  Future<void> _pickRequirementPdf(HonorRequirement requirement) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await _uploadRequirementEvidence(requirement, File(path));
  }

  Future<void> _uploadRequirementEvidence(
    HonorRequirement requirement,
    File file,
  ) async {
    final userId = ref.read(authNotifierProvider).valueOrNull?.id;
    if (userId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('honors.evidence.no_session'.tr()),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _uploadingRequirementId = requirement.id);

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

    setState(() => _uploadingRequirementId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'honors.requirements.requirement_evidence_success'.tr()
              : 'honors.requirements.requirement_evidence_error'.tr(),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final requirementsAsync =
        ref.watch(honorRequirementsProvider(widget.honorId));
    final progressAsync = ref.watch(userHonorProgressProvider(widget.honorId));
    final userHonorsAsync = ref.watch(userHonorsProvider);
    final userHonor = ref.watch(userHonorForHonorProvider(widget.honorId));

    final honorsAsync = ref.watch(allHonorsProvider);
    final honor = honorsAsync.valueOrNull
        ?.where((h) => h.id == widget.honorId)
        .firstOrNull;
    final categoryName = honor?.categoryName ??
        (honor?.categoryId != null
            ? ref.watch(categoryByIdProvider(honor!.categoryId))?.name
            : null);
    final categoryColor = getCategoryColor(
      categoryId: honor?.categoryId,
      categoryName: categoryName,
    );

    if (userHonorsAsync.isLoading) {
      return Scaffold(
        backgroundColor: context.sac.background,
        appBar: _requirementsTopBar(context, widget.honorName),
        body: const _LoadingBody(),
      );
    }

    if (userHonorsAsync.hasError || userHonor == null) {
      return _ModeGuardScaffold(
        honorName: widget.honorName,
        categoryColor: categoryColor,
        title: 'honors.requirements.mode_guard_title'.tr(),
        message: 'honors.requirements.mode_guard_not_found'.tr(),
      );
    }

    if (userHonor.completionMode != HonorCompletionMode.inApp) {
      return _ModeGuardScaffold(
        honorName: widget.honorName,
        categoryColor: categoryColor,
        title: 'honors.requirements.mode_guard_title'.tr(),
        message: userHonor.completionMode == HonorCompletionMode.external
            ? 'honors.requirements.mode_guard_external'.tr()
            : 'honors.requirements.mode_guard_undecided'.tr(),
      );
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await SacDialog.show(
          context,
          title: 'honors.requirements.unsaved_title'.tr(),
          content: 'honors.requirements.unsaved_content'.tr(),
          cancelLabel: 'honors.requirements.unsaved_stay'.tr(),
          confirmLabel: 'honors.requirements.unsaved_exit'.tr(),
          confirmIsDestructive: true,
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: context.sac.background,
        appBar: _requirementsTopBar(context, widget.honorName),
        body: Column(
          children: [
            Expanded(
              child: requirementsAsync.when(
                loading: () => const _LoadingBody(),
                error: (err, _) => _ErrorBody(
                  message: err.toString().replaceAll('Exception: ', ''),
                  onRetry: () {
                    ref.invalidate(honorRequirementsProvider(widget.honorId));
                    ref.invalidate(userHonorProgressProvider(widget.honorId));
                  },
                ),
                data: (requirements) {
                  return progressAsync.when(
                    loading: () => const _LoadingBody(),
                    error: (err, _) => _ErrorBody(
                      message: err.toString().replaceAll('Exception: ', ''),
                      onRetry: () {
                        ref.invalidate(
                            userHonorProgressProvider(widget.honorId));
                      },
                    ),
                    data: (progressList) {
                      _initLocalState(requirements, progressList);
                      final progressByRequirementId = {
                        for (final progress in progressList)
                          progress.requirementId: progress,
                      };

                      final totalAll = _localState.isNotEmpty
                          ? _countTotal(requirements)
                          : progressList.length;
                      final completedAll = _localState.isNotEmpty
                          ? _countCompletedAll(requirements)
                          : progressList.where((p) => p.completed).length;

                      return Column(
                        children: [
                          // Progress bar
                          _ProgressSection(
                            completed: completedAll,
                            total: totalAll,
                            categoryColor: categoryColor,
                          ),

                          // Hierarchical requirements list
                          Expanded(
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 120),
                              itemCount: requirements.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                thickness: 1,
                                color: context.sac.divider,
                              ),
                              itemBuilder: (context, index) {
                                return _buildRequirementBlock(
                                  context,
                                  requirements[index],
                                  depth: 0,
                                  categoryColor: categoryColor,
                                  progressByRequirementId:
                                      progressByRequirementId,
                                  enabled: userHonor.canSubmit,
                                );
                              },
                            ),
                          ),

                          _SaveBar(
                            hasChanges:
                                userHonor.canSubmit && _hasUnsavedChanges,
                            saving: _saving,
                            categoryColor: categoryColor,
                            onSave: () => _saveChanges(requirements),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tree builder ──────────────────────────────────────────────────────────

  /// Builds a requirement block: the item itself + optional children tree.
  Widget _buildRequirementBlock(
    BuildContext context,
    HonorRequirement req, {
    required int depth,
    required Color categoryColor,
    required Map<int, UserHonorRequirementProgress> progressByRequirementId,
    required bool enabled,
  }) {
    final state = _localState[req.id] ??
        const _RequirementState(
          completed: false,
          notes: '',
          textResponse: '',
        );

    final hasChildren = req.hasSubItems && req.children.isNotEmpty;
    final evidenceCount =
        progressByRequirementId[req.id]?.evidences.length ?? 0;

    // Count completed children for ChoiceGroupHeader.
    int completedChildCount = 0;
    if (hasChildren) {
      for (final child in req.children) {
        if (_localState[child.id]?.completed == true) completedChildCount++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The requirement row itself.
        Stack(
          children: [
            RequirementTreeItem(
              key: ValueKey(req.id),
              requirement: req,
              completed: state.completed,
              responseController: _responseControllers[req.id],
              depth: depth,
              categoryColor: categoryColor,
              enabled: enabled,
              onToggle: () => _toggleRequirement(req.id),
              evidenceCount: evidenceCount,
              isUploadingEvidence: _uploadingRequirementId == req.id,
              onAddEvidence: req.requiresEvidence
                  ? () => _showRequirementEvidenceOptions(req)
                  : null,
            ),

            // Expand/collapse chevron for items with children.
            if (hasChildren)
              Positioned(
                right: 0,
                top: 12,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _toggleChildrenExpand(req.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: AnimatedRotation(
                      turns: state.childrenExpanded ? 0.5 : 0,
                      duration: SacMotion.reduceMotionOf(context)
                          ? Duration.zero
                          : SacMotion.standard,
                      curve: SacMotion.easeOut,
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowDown01,
                        size: 18,
                        color: context.sac.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // Children block (shown when expanded).
        if (hasChildren && state.childrenExpanded) ...[
          // Choice group header if applicable.
          if (req.isChoiceGroup && req.choiceMin != null)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: ChoiceGroupHeader(
                choiceMin: req.choiceMin!,
                totalChildren: req.children.length,
                completedChildren: completedChildCount,
              ),
            ),

          // Rail height follows the children column; avoid IntrinsicHeight +
          // Expanded which gives the list a tight max height and overflows.
          Padding(
            padding: const EdgeInsets.only(left: 11),
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 1.5,
                  child: ColoredBox(color: context.sac.border),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < req.children.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: context.sac.divider,
                          ),
                        _buildRequirementBlock(
                          context,
                          req.children[i],
                          depth: depth + 1,
                          categoryColor: categoryColor,
                          progressByRequirementId: progressByRequirementId,
                          enabled: enabled,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeGuardScaffold extends StatelessWidget {
  final String honorName;
  final Color categoryColor;
  final String title;
  final String message;

  const _ModeGuardScaffold({
    required this.honorName,
    required this.categoryColor,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: SacTopBar(
        title: honorName,
        onBack: () => Navigator.of(context).maybePop(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedRoute01,
              size: 48,
              color: categoryColor,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.sac.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.sac.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            SacButton.outline(
              text: 'honors.requirements.mode_guard_back'.tr(),
              textColor: categoryColor,
              borderColor: categoryColor,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Progress Section ──────────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  final int completed;
  final int total;
  final Color categoryColor;

  const _ProgressSection({
    required this.completed,
    required this.total,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? completed / total : 0.0;
    final percentage = (fraction * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: context.sac.surface,
        border: Border(
          bottom: BorderSide(
            color: context.sac.border.withValues(alpha: 0.7),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'honors.requirements.progress_text'.tr(namedArgs: {
                  'completed': '$completed',
                  'total': '$total',
                }),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.sac.text,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: categoryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _AnimatedProgressBar(
            fraction: fraction,
            color: categoryColor,
          ),
        ],
      ),
    );
  }
}

class _AnimatedProgressBar extends StatefulWidget {
  final double fraction;
  final Color color;

  const _AnimatedProgressBar({
    required this.fraction,
    required this.color,
  });

  @override
  State<_AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<_AnimatedProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SacMotion.standard,
    );
    _animation = AlwaysStoppedAnimation(widget.fraction);
    _controller.value = 1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration =
        SacMotion.reduceMotionOf(context) ? Duration.zero : SacMotion.standard;
  }

  @override
  void didUpdateWidget(covariant _AnimatedProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fraction == widget.fraction) return;

    _animation = Tween<double>(
      begin: _animation.value,
      end: widget.fraction,
    ).animate(
      CurvedAnimation(parent: _controller, curve: SacMotion.easeOut),
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _animation]),
      builder: (context, _) {
        final value = _animation.value.clamp(0.0, 1.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: SizedBox(
            height: 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: widget.color.withValues(alpha: 0.15),
                ),
                FractionallySizedBox(
                  widthFactor: value,
                  alignment: Alignment.centerLeft,
                  child: ColoredBox(color: widget.color),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Save Bar ──────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final bool hasChanges;
  final bool saving;
  final Color categoryColor;
  final VoidCallback onSave;

  const _SaveBar({
    required this.hasChanges,
    required this.saving,
    required this.categoryColor,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.sac.surface,
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SacButton.primary(
        text: 'honors.requirements.save_button'.tr(),
        isLoading: saving,
        backgroundColor:
            hasChanges ? categoryColor : context.sac.surfaceVariant,
        textColor: hasChanges ? Colors.white : context.sac.textTertiary,
        onPressed: (hasChanges && !saving) ? onSave : null,
      ),
    );
  }
}

// ── Loading Body ──────────────────────────────────────────────────────────────

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: 6,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: context.sac.divider,
      ),
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: context.sac.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: context.sac.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: context.sac.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error Body ────────────────────────────────────────────────────────────────

class _ErrorBody extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBody({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message.isNotEmpty
                  ? message
                  : 'honors.requirements.error_load'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.sac.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'honors.requirements.retry'.tr(),
                style: const TextStyle(
                  color: AppColors.info,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
