import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/domain/entities/user_honor_requirement_progress.dart';
import 'package:sacdia_app/features/honors/domain/utils/honor_category_colors.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/choice_group_header.dart';
import 'package:sacdia_app/features/honors/presentation/widgets/requirement_tree_item.dart';
import '../../../auth/presentation/providers/auth_providers.dart';

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

class _HonorRequirementsViewState
    extends ConsumerState<HonorRequirementsView> {
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
      _responseControllers[req.id] =
          TextEditingController(text: textResponse);
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
    final honor = ref
        .read(allHonorsProvider)
        .valueOrNull
        ?.where((h) => h.id == widget.honorId)
        .firstOrNull;
    final categoryColor = getCategoryColor(categoryId: honor?.categoryId);

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
          content: const Text('Progreso guardado correctamente'),
          backgroundColor: categoryColor,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final requirementsAsync =
        ref.watch(honorRequirementsProvider(widget.honorId));
    final progressAsync =
        ref.watch(userHonorProgressProvider(widget.honorId));

    final honorsAsync = ref.watch(allHonorsProvider);
    final honor = honorsAsync.valueOrNull
        ?.where((h) => h.id == widget.honorId)
        .firstOrNull;
    final categoryColor = getCategoryColor(categoryId: honor?.categoryId);

    // Resolve userId for evidence operations.
    final userId =
        ref.watch(authNotifierProvider).valueOrNull?.id ?? '';

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cambios sin guardar'),
            content: const Text(
              'Tienes cambios sin guardar. ¿Seguro que quieres salir?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Quedarme'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Salir'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: context.sac.background,
        body: Column(
          children: [
            _DarkHeader(
              honorName: widget.honorName,
              categoryColor: categoryColor,
            ),

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
                      message:
                          err.toString().replaceAll('Exception: ', ''),
                      onRetry: () {
                        ref.invalidate(
                            userHonorProgressProvider(widget.honorId));
                      },
                    ),
                    data: (progressList) {
                      _initLocalState(requirements, progressList);

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
                              padding: const EdgeInsets.fromLTRB(
                                  16, 8, 16, 120),
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
                                  userId: userId,
                                  categoryColor: categoryColor,
                                );
                              },
                            ),
                          ),

                          _SaveBar(
                            hasChanges: _hasUnsavedChanges,
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
    required String userId,
    required Color categoryColor,
  }) {
    final state = _localState[req.id] ??
        const _RequirementState(
          completed: false,
          notes: '',
          textResponse: '',
        );

    final hasChildren = req.hasSubItems && req.children.isNotEmpty;

    // Count completed children for ChoiceGroupHeader.
    int completedChildCount = 0;
    if (hasChildren) {
      for (final child in req.children) {
        if (_localState[child.id]?.completed == true) completedChildCount++;
      }
    }

    // Evidence count: use the synchronous cached value if already loaded.
    // RequirementTreeItem watches the provider reactively so the badge updates
    // live — here we only need the snapshot to drive the warning guard.
    final evidenceCount = ref
        .read(requirementEvidenceProvider((
          userId: userId,
          honorId: widget.honorId,
          requirementId: req.id,
        )))
        .valueOrNull
        ?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The requirement row itself.
        Stack(
          children: [
            RequirementTreeItem(
              requirement: req,
              completed: state.completed,
              textResponse: state.textResponse,
              responseController: _responseControllers[req.id],
              depth: depth,
              userId: userId,
              honorId: widget.honorId,
              categoryColor: categoryColor,
              evidenceCount: evidenceCount,
              onToggle: () => _toggleRequirement(req.id),
            ),

            // Expand/collapse chevron for items with children.
            if (hasChildren)
              Positioned(
                right: 0,
                top: 10,
                child: GestureDetector(
                  onTap: () => _toggleChildrenExpand(req.id),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      state.childrenExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: categoryColor,
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

          // Thin vertical line connecting children.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Indent track line.
                Container(
                  width: 24,
                  margin: const EdgeInsets.only(left: 11),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: categoryColor.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // Children list.
                Expanded(
                  child: Column(
                    children: [
                      for (int i = 0; i < req.children.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            indent: 0,
                            endIndent: 0,
                            color: context.sac.divider,
                          ),
                        _buildRequirementBlock(
                          context,
                          req.children[i],
                          depth: depth + 1,
                          userId: userId,
                          categoryColor: categoryColor,
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

// ── Dark Header ───────────────────────────────────────────────────────────────

class _DarkHeader extends StatelessWidget {
  final String honorName;
  final Color categoryColor;

  const _DarkHeader({
    required this.honorName,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: categoryColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).maybePop();
                },
                child: const Padding(
                  padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      honorName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Requisitos',
                      style: TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      color: context.sac.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed de $total completados',
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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 8,
              backgroundColor: categoryColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(categoryColor),
            ),
          ),
        ],
      ),
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                hasChanges ? categoryColor : context.sac.surfaceVariant,
            foregroundColor:
                hasChanges ? Colors.white : context.sac.textTertiary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          onPressed: (hasChanges && !saving) ? onSave : null,
          child: saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Guardar cambios',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
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
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message.isNotEmpty
                  ? message
                  : 'No se pudieron cargar los requisitos',
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
              child: const Text(
                'Reintentar',
                style: TextStyle(
                  color: AppColors.sacBlue,
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
