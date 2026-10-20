import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_progress_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/dependent_progress_summary.dart';
import '../family_error_messages.dart';
import '../providers/family_providers.dart';

/// Resumen que el tutor ve de un menor (FP3-26): progreso de clases,
/// especialidades y asistencia del año.
///
/// No hay salud, evidencias, notas, contacto ni mensajes: el modelo solo lee
/// esas llaves del servidor. Un tutor pendiente (409) o ajeno (404) ve el
/// mensaje por código, nunca el texto crudo.
class GuardianSummaryView extends ConsumerWidget {
  const GuardianSummaryView({super.key, required this.dependentId});

  final String dependentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final summary = ref.watch(dependentProgressSummaryProvider(dependentId));

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: summary.maybeWhen(
          data: (s) => 'family.summary.title'
              .tr(namedArgs: {'name': (s.name ?? '—').trim()}),
          orElse: () => 'family.summary.subtitle'.tr(),
        ),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: summary.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => _SummaryError(
          error: error,
          onRetry: () =>
              ref.invalidate(dependentProgressSummaryProvider(dependentId)),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dependentProgressSummaryProvider(dependentId));
            await ref
                .read(dependentProgressSummaryProvider(dependentId).future)
                .then<void>((_) {}, onError: (_) {});
          },
          child: _SummaryBody(summary: data),
        ),
      ),
    );
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final DependentProgressSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final hPad = Responsive.horizontalPadding(context);

    return ListView(
      key: const ValueKey('guardian_summary_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
      children: [
        _SectionLabel(label: 'family.summary.classes_title'.tr()),
        const SizedBox(height: 8),
        if (summary.classes.isEmpty)
          SacCard(
            child: Text(
              'family.summary.no_classes'.tr(),
              style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          )
        else
          for (final item in summary.classes) _ClassTile(item: item),
        const SizedBox(height: 20),
        _SectionLabel(label: 'family.summary.honors_title'.tr()),
        const SizedBox(height: 8),
        SacCard(
          child: Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                  text: 'family.summary.honors_completed'.tr(
                    namedArgs: {'count': '${summary.honorsCompleted}'},
                  ),
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: HugeIcons.strokeRoundedClock01,
                  text: 'family.summary.honors_in_progress'.tr(
                    namedArgs: {'count': '${summary.honorsInProgress}'},
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _SectionLabel(label: 'family.summary.attendance_title'.tr()),
        const SizedBox(height: 8),
        _AttendanceCard(attendance: summary.attendance),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedShield01,
              size: 18,
              color: c.textSecondary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'family.summary.privacy_note'.tr(),
                key: const ValueKey('summary_privacy_note'),
                style: textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.sac.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
    );
  }
}

class _ClassTile extends StatelessWidget {
  const _ClassTile({required this.item});

  final ClassProgressSummary item;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    return SacCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              Text(
                '${item.progressPercent}%',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SacAccent.of(context).color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SacProgressBar(progress: item.progressPercent / 100, height: 8),
          const SizedBox(height: 6),
          Text(
            'family.summary.sections_progress'.tr(namedArgs: {
              'done': '${item.sectionsCompleted}',
              'total': '${item.sectionsTotal}',
            }),
            style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.text});

  final List<List<dynamic>> icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HugeIcon(icon: icon, size: 20, color: SacAccent.of(context).color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.sac.text,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.attendance});

  final AttendanceSummary attendance;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    if (attendance.activitiesTotal <= 0) {
      return SacCard(
        child: Text(
          'family.summary.no_activities'.tr(),
          style: textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        ),
      );
    }
    final locale = context.locale.toString();
    String? period;
    final from = attendance.from;
    final to = attendance.to;
    if (from != null && to != null) {
      period = 'family.summary.attendance_period'.tr(namedArgs: {
        'from': DateFormat.yMMMd(locale).format(from),
        'to': DateFormat.yMMMd(locale).format(to),
      });
    }
    return SacCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'family.summary.attendance_value'.tr(namedArgs: {
                    'attended': '${attendance.activitiesAttended}',
                    'total': '${attendance.activitiesTotal}',
                  }),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              Text(
                '${attendance.percent}%',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: SacAccent.of(context).color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SacProgressBar(progress: attendance.percent / 100, height: 8),
          if (period != null) ...[
            const SizedBox(height: 6),
            Text(
              period,
              style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryError extends StatelessWidget {
  const _SummaryError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    // 404 (ajeno o sin tutoría) y 409 (consentimiento sin verificar) no se
    // arreglan reintentando.
    final code = error is Failure ? (error as Failure).errorCode : null;
    final retryable = code != 'GUARDIANSHIP_NOT_FOUND' &&
        code != 'GUARDIANSHIP_CONSENT_NOT_VERIFIED';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              familyErrorMessage(error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.sac.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
            if (retryable)
              SacButton.outline(text: 'common.retry'.tr(), onPressed: onRetry)
            else
              SacButton.outline(
                text: 'common.back'.tr(),
                onPressed: () => context.pop(),
              ),
          ],
        ),
      ),
    );
  }
}
