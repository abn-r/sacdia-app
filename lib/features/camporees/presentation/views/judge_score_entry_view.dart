import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_back_button.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_rubric.dart';
import 'package:sacdia_app/features/camporees/domain/entities/camporee_score_submission.dart';

import '../providers/camporees_providers.dart';

/// Captura de puntaje por rúbrica para juez principal.
class JudgeScoreEntryView extends ConsumerStatefulWidget {
  final int eventId;
  final int clubSectionId;
  final String? eventTitle;

  const JudgeScoreEntryView({
    super.key,
    required this.eventId,
    required this.clubSectionId,
    this.eventTitle,
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

  String _formatPoints(double value) {
    return NumberFormat.decimalPatternDigits(
      locale: context.locale.toString(),
      decimalDigits: value.truncateToDouble() == value ? 0 : 2,
    ).format(value);
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
    final title = widget.eventTitle?.trim().isNotEmpty == true
        ? widget.eventTitle!
        : 'camporees.judge.event_fallback'.tr(
            namedArgs: {'eventId': '${widget.eventId}'},
          );

    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: context.sac.background,
        foregroundColor: context.sac.text,
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

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _ScoreHeader(
                  title: title,
                  clubSectionId: widget.clubSectionId,
                ),
                const SizedBox(height: 16),
                _TotalCard(
                  total: _formatPoints(total),
                  maxTotal: _formatPoints(maxTotal),
                ),
                const SizedBox(height: 16),
                for (final rubric in rubrics) ...[
                  _RubricInputCard(
                    rubric: rubric,
                    controller: _pointControllers[rubric.rubricId]!,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _notesController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'camporees.judge.notes_label'.tr(),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 18),
                SacButton.primary(
                  text: 'camporees.judge.submit_score'.tr(),
                  icon: Icons.send,
                  isLoading: submitState.isLoading,
                  isEnabled: !submitState.isLoading,
                  onPressed:
                      submitState.isLoading ? null : () => _submit(rubrics),
                ),
                if (submitState.errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    submitState.errorMessage!,
                    style: TextStyle(
                      color: context.sac.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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

class _ScoreHeader extends StatelessWidget {
  final String title;
  final int clubSectionId;

  const _ScoreHeader({
    required this.title,
    required this.clubSectionId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: context.sac.text,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'camporees.judge.section_label'.tr(
              namedArgs: {'sectionId': '$clubSectionId'},
            ),
            style: TextStyle(
              color: context.sac.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String total;
  final String maxTotal;

  const _TotalCard({
    required this.total,
    required this.maxTotal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.sac.success.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.sac.success.withValues(alpha: 0.20)),
      ),
      child: Text(
        'camporees.judge.total_label'.tr(
          namedArgs: {'total': total, 'maxTotal': maxTotal},
        ),
        style: TextStyle(
          color: context.sac.success,
          fontWeight: FontWeight.w900,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _RubricInputCard extends StatelessWidget {
  final CamporeeRubric rubric;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _RubricInputCard({
    required this.rubric,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rubric.title,
            style: TextStyle(
              color: c.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (rubric.description != null &&
              rubric.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              rubric.description!,
              style: TextStyle(color: c.textSecondary, height: 1.35),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9\.,]')),
            ],
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: 'camporees.judge.awarded_points'.tr(),
              helperText: 'camporees.judge.max_points_hint'.tr(
                namedArgs: {'max': '${rubric.maxPoints}'},
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRubrics extends StatelessWidget {
  final VoidCallback onRetry;

  const _EmptyRubrics({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rule, size: 48, color: context.sac.textTertiary),
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
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRubrics extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRubrics({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: context.sac.error),
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
              icon: Icons.refresh,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
