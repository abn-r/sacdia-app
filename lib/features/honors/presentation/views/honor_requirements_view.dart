import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:sacdia_app/features/honors/domain/entities/honor_requirement.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';

// ── Local state helpers ───────────────────────────────────────────────────────

/// Tracks local state for a single requirement row.
class _RequirementState {
  final bool completed;
  final String notes;
  final bool expanded;
  final bool showNotes;

  const _RequirementState({
    required this.completed,
    required this.notes,
    this.expanded = false,
    this.showNotes = false,
  });

  _RequirementState copyWith({
    bool? completed,
    String? notes,
    bool? expanded,
    bool? showNotes,
  }) {
    return _RequirementState(
      completed: completed ?? this.completed,
      notes: notes ?? this.notes,
      expanded: expanded ?? this.expanded,
      showNotes: showNotes ?? this.showNotes,
    );
  }
}

// ── View ──────────────────────────────────────────────────────────────────────

/// Vista de checklist de requisitos de una especialidad inscripta.
///
/// Muestra la lista de requisitos con checkboxes, notas opcionales
/// y un botón "Guardar cambios" que persiste los cambios via [RequirementProgressNotifier].
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

  /// TextEditingControllers keyed by requirementId.
  final Map<int, TextEditingController> _controllers = {};

  /// Snapshot of completed+notes at last save — used to detect dirty state.
  final Map<int, ({bool completed, String notes})> _savedSnapshot = {};

  bool _saving = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  UserHonorProgressParams get _progressParams => UserHonorProgressParams(
        userId: ref.read(authNotifierProvider).value?.id ?? '',
        userHonorId: widget.userHonorId,
      );

  /// Initialise local state from the server progress map, once per load.
  void _initLocalState(
    List<HonorRequirement> requirements,
    Map<String, dynamic> progress,
  ) {
    if (_localState.isNotEmpty) return;

    final progressList =
        (progress['requirements'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final progressMap = <int, Map<String, dynamic>>{};
    for (final item in progressList) {
      final id = (item['requirement_id'] as num?)?.toInt();
      if (id != null) progressMap[id] = item;
    }

    for (final req in requirements) {
      final p = progressMap[req.id];
      final completed = (p?['completed'] as bool?) ?? false;
      final notes = (p?['notes'] as String?) ?? '';

      _localState[req.id] = _RequirementState(
        completed: completed,
        notes: notes,
      );
      _controllers[req.id] = TextEditingController(text: notes);
      _savedSnapshot[req.id] = (completed: completed, notes: notes);
    }
  }

  bool get _hasUnsavedChanges {
    for (final entry in _localState.entries) {
      final snap = _savedSnapshot[entry.key];
      if (snap == null) return true;
      if (entry.value.completed != snap.completed) return true;
      if ((_controllers[entry.key]?.text ?? entry.value.notes) != snap.notes) {
        return true;
      }
    }
    return false;
  }

  int get _localCompletedCount =>
      _localState.values.where((s) => s.completed).length;

  void _toggleRequirement(int requirementId) {
    setState(() {
      final current = _localState[requirementId];
      if (current == null) return;
      _localState[requirementId] =
          current.copyWith(completed: !current.completed);
    });
    HapticFeedback.selectionClick();
  }

  void _toggleExpand(int requirementId) {
    setState(() {
      final current = _localState[requirementId];
      if (current == null) return;
      _localState[requirementId] =
          current.copyWith(expanded: !current.expanded);
    });
  }

  void _toggleNotes(int requirementId) {
    setState(() {
      final current = _localState[requirementId];
      if (current == null) return;
      _localState[requirementId] =
          current.copyWith(showNotes: !current.showNotes);
    });
  }

  Future<void> _saveChanges(List<HonorRequirement> requirements) async {
    setState(() => _saving = true);

    final updates = <Map<String, dynamic>>[];
    for (final req in requirements) {
      final s = _localState[req.id];
      final ctrl = _controllers[req.id];
      if (s == null) continue;
      updates.add({
        'requirementId': req.id,
        'completed': s.completed,
        'notes': ctrl?.text ?? s.notes,
      });
    }

    final success = await ref
        .read(requirementProgressNotifierProvider.notifier)
        .bulkUpdate(
          progressParams: _progressParams,
          updates: updates,
        );

    if (!mounted) return;

    setState(() => _saving = false);

    if (success) {
      // Update saved snapshot so dirty detection resets.
      for (final req in requirements) {
        final s = _localState[req.id];
        final ctrl = _controllers[req.id];
        if (s == null) continue;
        _savedSnapshot[req.id] = (
          completed: s.completed,
          notes: ctrl?.text ?? s.notes,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Progreso guardado correctamente'),
          backgroundColor: AppColors.sacGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );

      // Invalidate both providers so they re-fetch fresh data.
      ref.invalidate(userHonorProgressProvider(_progressParams));
      ref.invalidate(honorRequirementsProvider(widget.honorId));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final requirementsAsync =
        ref.watch(honorRequirementsProvider(widget.honorId));
    final progressAsync =
        ref.watch(userHonorProgressProvider(_progressParams));

    return Scaffold(
      backgroundColor: context.sac.background,
      body: Column(
        children: [
          _DarkHeader(honorName: widget.honorName),

          // ── Body ─────────────────────────────────────────────
          Expanded(
            child: requirementsAsync.when(
              loading: () => const _LoadingBody(),
              error: (err, _) => _ErrorBody(
                message: err.toString().replaceAll('Exception: ', ''),
                onRetry: () {
                  ref.invalidate(honorRequirementsProvider(widget.honorId));
                  ref.invalidate(
                      userHonorProgressProvider(_progressParams));
                },
              ),
              data: (requirements) {
                return progressAsync.when(
                  loading: () => const _LoadingBody(),
                  error: (err, _) => _ErrorBody(
                    message: err.toString().replaceAll('Exception: ', ''),
                    onRetry: () {
                      ref.invalidate(
                          userHonorProgressProvider(_progressParams));
                    },
                  ),
                  data: (progress) {
                    _initLocalState(requirements, progress);

                    final totalRequirements = requirements.length;
                    final serverCompletedCount =
                        (progress['completed_count'] as num?)?.toInt() ?? 0;

                    // Use local count if we have local state, else server count.
                    final displayCompleted = _localState.isNotEmpty
                        ? _localCompletedCount
                        : serverCompletedCount;

                    return Column(
                      children: [
                        // Progress section
                        _ProgressSection(
                          completed: displayCompleted,
                          total: totalRequirements,
                        ),

                        // Requirements list
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                            itemCount: requirements.length,
                            separatorBuilder: (_, __) => Divider(
                              height: 1,
                              thickness: 1,
                              color: context.sac.divider,
                            ),
                            itemBuilder: (context, index) {
                              final req = requirements[index];
                              final state = _localState[req.id] ??
                                  const _RequirementState(
                                    completed: false,
                                    notes: '',
                                  );
                              return _RequirementRow(
                                requirement: req,
                                state: state,
                                controller: _controllers[req.id],
                                onToggle: () => _toggleRequirement(req.id),
                                onToggleExpand: () => _toggleExpand(req.id),
                                onToggleNotes: () => _toggleNotes(req.id),
                              );
                            },
                          ),
                        ),

                        // Save button — floating above content
                        _SaveBar(
                          hasChanges: _hasUnsavedChanges,
                          saving: _saving,
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
    );
  }
}

// ── Dark Header ───────────────────────────────────────────────────────────────

class _DarkHeader extends StatelessWidget {
  final String honorName;

  const _DarkHeader({required this.honorName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sacBlack,
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

  const _ProgressSection({
    required this.completed,
    required this.total,
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
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sacGreen,
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
              backgroundColor: AppColors.sacGreen.withValues(alpha: 0.15),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.sacGreen),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requirement Row ───────────────────────────────────────────────────────────

class _RequirementRow extends StatelessWidget {
  final HonorRequirement requirement;
  final _RequirementState state;
  final TextEditingController? controller;
  final VoidCallback onToggle;
  final VoidCallback onToggleExpand;
  final VoidCallback onToggleNotes;

  const _RequirementRow({
    required this.requirement,
    required this.state,
    required this.controller,
    required this.onToggle,
    required this.onToggleExpand,
    required this.onToggleNotes,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Main row: checkbox + number + text ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: state.completed,
                  onChanged: (_) => onToggle(),
                  activeColor: AppColors.sacGreen,
                  checkColor: Colors.white,
                  side: BorderSide(
                    color: state.completed
                        ? AppColors.sacGreen
                        : context.sac.border,
                    width: 1.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 10),

              // Requirement number badge
              Container(
                margin: const EdgeInsets.only(top: 1),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppColors.sacBlack.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  '${requirement.requirementNumber}.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.sac.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Requirement text with expand toggle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onToggleExpand,
                      child: Text(
                        requirement.text,
                        maxLines: state.expanded ? null : 3,
                        overflow: state.expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.55,
                          color: state.completed
                              ? context.sac.textTertiary
                              : context.sac.text,
                          decoration: state.completed
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          decorationColor: context.sac.textTertiary,
                        ),
                      ),
                    ),
                    if (_needsExpandToggle(requirement.text))
                      GestureDetector(
                        onTap: onToggleExpand,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            state.expanded ? 'Ver menos' : 'Ver mas',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.sacBlue,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Notes toggle icon
              GestureDetector(
                onTap: onToggleNotes,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8, top: 1),
                  child: Icon(
                    state.showNotes
                        ? Icons.notes_rounded
                        : Icons.notes_outlined,
                    size: 18,
                    color: state.showNotes
                        ? AppColors.sacBlue
                        : context.sac.textTertiary,
                  ),
                ),
              ),
            ],
          ),

          // ── Notes TextField (conditional) ─────────────────
          if (state.showNotes)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 34),
              child: TextField(
                controller: controller,
                maxLines: 3,
                minLines: 1,
                maxLength: 2000,
                style: TextStyle(
                  fontSize: 12,
                  color: context.sac.text,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Agregar nota (opcional)',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: context.sac.textTertiary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.sac.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: context.sac.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                        color: AppColors.sacBlue, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                  counterStyle: TextStyle(
                    fontSize: 10,
                    color: context.sac.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Heuristic: only show expand toggle when text is likely to exceed 3 lines
  /// (roughly 150 characters is a safe threshold for ~13sp text at 320dp width).
  bool _needsExpandToggle(String text) => text.length > 120;
}

// ── Save Bar ──────────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final bool hasChanges;
  final bool saving;
  final VoidCallback onSave;

  const _SaveBar({
    required this.hasChanges,
    required this.saving,
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
                hasChanges ? AppColors.sacGreen : context.sac.surfaceVariant,
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
              message.isNotEmpty ? message : 'No se pudieron cargar los requisitos',
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
