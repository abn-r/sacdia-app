import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/animations/staggered_list_animation.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_progress_bar.dart';
import 'package:sacdia_app/core/widgets/sac_text_field.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_rubric.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_score_submission.dart';
import 'package:sacdia_app/features/camporees/domain/utils/camporee_score_format.dart';

import '../providers/camporees_providers.dart';

/// Captura de puntaje por rúbrica para juez principal.
class JudgeScoreEntryView extends ConsumerStatefulWidget {
  final int eventId;
  final int clubSectionId;
  final String? eventTitle;
  final String? clubLabel;

  const JudgeScoreEntryView({
    super.key,
    required this.eventId,
    required this.clubSectionId,
    this.eventTitle,
    this.clubLabel,
  });

  @override
  ConsumerState<JudgeScoreEntryView> createState() =>
      _JudgeScoreEntryViewState();
}

class _JudgeScoreEntryViewState extends ConsumerState<JudgeScoreEntryView> {
  final _notesController = TextEditingController();
  final Map<int, TextEditingController> _pointControllers = {};

  CamporeeJudgeScoreParams get _params => CamporeeJudgeScoreParams(
        eventId: widget.eventId,
        clubSectionId: widget.clubSectionId,
      );

  @override
  void dispose() {
    _notesController.dispose();
    for (final controller in _pointControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncControllers(List<CamporeeRubric> rubrics) {
    final activeIds = rubrics.map((rubric) => rubric.rubricId).toSet();
    final staleIds =
        _pointControllers.keys.where((id) => !activeIds.contains(id)).toList();
    for (final id in staleIds) {
      _pointControllers.remove(id)?.dispose();
    }
    for (final rubric in rubrics) {
      _pointControllers.putIfAbsent(
        rubric.rubricId,
        () => TextEditingController(text: '0'),
      );
    }
  }

  double _pointsFor(int rubricId) {
    final raw = _pointControllers[rubricId]?.text.replaceAll(',', '.') ?? '0';
    return double.tryParse(raw) ?? 0;
  }

  void _writePoints(int rubricId, double value) {
    final text = formatCamporeeScoreNumber(value);
    final controller = _pointControllers[rubricId];
    if (controller == null) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    setState(() {});
  }

  void _adjustPoints(CamporeeRubric rubric, double delta) {
    final next =
        (_pointsFor(rubric.rubricId) + delta).clamp(0, rubric.maxPoints);
    _writePoints(rubric.rubricId, next.toDouble());
  }

  double _total(List<CamporeeRubric> rubrics) {
    return rubrics.fold<double>(
      0,
      (total, rubric) => total + _pointsFor(rubric.rubricId),
    );
  }

  Future<void> _submit(List<CamporeeRubric> rubrics) async {
    final items = <CamporeeScoreSubmissionItem>[];
    for (final rubric in rubrics) {
      final awarded = _pointsFor(rubric.rubricId);
      if (awarded < 0 || awarded > rubric.maxPoints) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('camporees.judge.score_invalid'.tr())),
        );
        return;
      }
      items.add(CamporeeScoreSubmissionItem(
        rubricId: rubric.rubricId,
        awardedPoints: awarded,
      ));
    }

    HapticFeedback.mediumImpact();
    final ok = await ref
        .read(camporeeScoreSubmissionProvider(_params).notifier)
        .submit(
          items: items,
          notes: _notesController.text.trim(),
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'camporees.judge.score_saved'.tr()
              : 'camporees.judge.score_save_failed'.tr(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rubricsAsync =
        ref.watch(camporeeEventRubricsProvider(widget.eventId));
    final submitState = ref.watch(camporeeScoreSubmissionProvider(_params));
    final c = context.sac;
    final title = widget.eventTitle?.trim().isNotEmpty == true
        ? widget.eventTitle!
        : 'camporees.judge.event_fallback'.tr(
            namedArgs: {'eventId': '${widget.eventId}'},
          );
    final clubLabel = widget.clubLabel?.trim().isNotEmpty == true
        ? widget.clubLabel!
        : 'camporees.judge.section_label'.tr(
            namedArgs: {'sectionId': '${widget.clubSectionId}'},
          );

    return Scaffold(
      backgroundColor: c.surfaceVariant,
      appBar: AppBar(
        backgroundColor: c.surfaceVariant,
        foregroundColor: c.text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const SacBackButton(),
        title: Text('camporees.judge.score_title'.tr()),
      ),
      body: SafeArea(
        child: rubricsAsync.when(
          data: (rubrics) {
            _syncControllers(rubrics);
            if (rubrics.isEmpty) {
              return _EmptyRubrics(
                onRetry: () => ref
                    .invalidate(camporeeEventRubricsProvider(widget.eventId)),
              );
            }

            final total = _total(rubrics);
            final maxTotal = rubrics.fold<double>(
              0,
              (sum, rubric) => sum + rubric.maxPoints,
            );

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      _ScoreIdentityCard(
                        title: title,
                        clubLabel: clubLabel,
                      ),
                      const SizedBox(height: 14),
                      for (var i = 0; i < rubrics.length; i++) ...[
                        StaggeredListItem(
                          index: i,
                          child: _RubricScoreCard(
                            rubric: rubrics[i],
                            controller: _pointControllers[rubrics[i].rubricId]!,
                            awarded: _pointsFor(rubrics[i].rubricId),
                            onChanged: (_) => setState(() {}),
                            onStep: (delta) => _adjustPoints(rubrics[i], delta),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      SacTextField(
                        controller: _notesController,
                        label: 'camporees.judge.notes_label'.tr(),
                        maxLines: 4,
                      ),
                      if (submitState.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          submitState.errorMessage!,
                          style: TextStyle(
                            color: c.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _ScoreSubmitBar(
                  total: formatCamporeeScoreNumber(total),
                  maxTotal: formatCamporeeScoreNumber(maxTotal),
                  isLoading: submitState.isLoading,
                  onSubmit:
                      submitState.isLoading ? null : () => _submit(rubrics),
                ),
              ],
            );
          },
          loading: () => const Center(child: SacLoading()),
          error: (error, _) => _ErrorRubrics(
            message: error.toString().replaceFirst('Exception: ', ''),
            onRetry: () =>
                ref.invalidate(camporeeEventRubricsProvider(widget.eventId)),
          ),
        ),
      ),
    );
  }
}

class _ScoreIdentityCard extends StatelessWidget {
  final String title;
  final String clubLabel;

  const _ScoreIdentityCard({
    required this.title,
    required this.clubLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;

    return SacCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedNoteEdit,
              size: 18,
              color: scheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: c.text,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        height: 1.15,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  clubLabel,
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RubricScoreCard extends StatelessWidget {
  final CamporeeRubric rubric;
  final TextEditingController controller;
  final double awarded;
  final ValueChanged<String> onChanged;
  final ValueChanged<double> onStep;

  const _RubricScoreCard({
    required this.rubric,
    required this.controller,
    required this.awarded,
    required this.onChanged,
    required this.onStep,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final scheme = Theme.of(context).colorScheme;
    final step = _stepFor(rubric.maxPoints);
    final overMax = awarded > rubric.maxPoints;
    final atMin = awarded <= 0;
    final atMax = awarded >= rubric.maxPoints;
    final progress = rubric.maxPoints <= 0
        ? 0.0
        : (awarded / rubric.maxPoints).clamp(0.0, 1.0);

    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rubric.title,
            style: TextStyle(
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.2,
            ),
          ),
          if (rubric.description != null &&
              rubric.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rubric.description!,
              style: TextStyle(
                color: c.textSecondary,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _ScoreStepButton(
                icon: HugeIcons.strokeRoundedMinusSign,
                enabled: !atMin,
                semanticLabel: 'camporees.judge.score_step_minus'.tr(
                  namedArgs: {'title': rubric.title},
                ),
                onTap: () => onStep(-step),
              ),
              Expanded(
                child: Semantics(
                  textField: true,
                  label: 'camporees.judge.score_field_semantics'.tr(
                    namedArgs: {
                      'title': rubric.title,
                      'max': formatCamporeeScoreNumber(rubric.maxPoints),
                    },
                  ),
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
                    ],
                    style: TextStyle(
                      color: overMax ? c.error : c.text,
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onChanged: onChanged,
                  ),
                ),
              ),
              _ScoreStepButton(
                icon: HugeIcons.strokeRoundedAdd01,
                enabled: !atMax,
                semanticLabel: 'camporees.judge.score_step_plus'.tr(
                  namedArgs: {'title': rubric.title},
                ),
                onTap: () => onStep(step),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SacProgressBar(
            progress: progress,
            height: 6,
            color: overMax ? c.error : scheme.primary,
            fillDuration: SacMotion.press,
          ),
          const SizedBox(height: 8),
          Text(
            'camporees.judge.max_points_hint'.tr(
              namedArgs: {'max': formatCamporeeScoreNumber(rubric.maxPoints)},
            ),
            style: TextStyle(
              color: overMax ? c.error : c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreStepButton extends StatelessWidget {
  final HugeIconData icon;
  final bool enabled;
  final String semanticLabel;
  final VoidCallback onTap;

  const _ScoreStepButton({
    required this.icon,
    required this.enabled,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = context.sac;
    final foreground = enabled ? scheme.onPrimaryContainer : c.textTertiary;
    final background = enabled ? scheme.primaryContainer : c.borderLight;

    return SacPressable(
      enabled: enabled,
      semanticLabel: semanticLabel,
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        ),
        child: HugeIcon(icon: icon, size: 20, color: foreground),
      ),
    );
  }
}

class _ScoreSubmitBar extends StatelessWidget {
  final String total;
  final String maxTotal;
  final bool isLoading;
  final VoidCallback? onSubmit;

  const _ScoreSubmitBar({
    required this.total,
    required this.maxTotal,
    required this.isLoading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.borderLight)),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'camporees.judge.total_caption'.tr(),
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'camporees.judge.total_value'.tr(
                    namedArgs: {'total': total, 'maxTotal': maxTotal},
                  ),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SacButton.primary(
                text: 'camporees.judge.submit_score'.tr(),
                icon: HugeIcons.strokeRoundedSent,
                isLoading: isLoading,
                isEnabled: onSubmit != null,
                onPressed: onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRubrics extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyRubrics({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        HugeIcon(
          icon: HugeIcons.strokeRoundedCheckList,
          size: 48,
          color: context.sac.textTertiary,
        ),
        const SizedBox(height: 12),
        Text(
          'camporees.judge.no_rubrics'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.sac.text,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 18),
        SacButton.outline(
          text: 'common.retry'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _ErrorRubrics extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRubrics({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 96),
        HugeIcon(
          icon: HugeIcons.strokeRoundedAlert02,
          size: 48,
          color: context.sac.error,
        ),
        const SizedBox(height: 12),
        Text(
          'camporees.judge.rubrics_error'.tr(),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: context.sac.text,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.sac.textSecondary),
        ),
        const SizedBox(height: 20),
        SacButton.primary(
          text: 'common.retry'.tr(),
          icon: HugeIcons.strokeRoundedRefresh,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

double _stepFor(double maxPoints) {
  return maxPoints == maxPoints.truncateToDouble() ? 1 : 0.5;
}
