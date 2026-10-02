import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';
import 'package:sacdia_app/providers/catalogs_provider.dart';
import 'package:sacdia_app/shared/models/catalogs/ecclesiastical_year_model.dart';

import '../../../members/presentation/providers/members_providers.dart';
import '../../domain/entities/unit.dart';
import '../../domain/weekly_points_history.dart';
import '../providers/unit_points_history_provider.dart';

/// Puntos por miembro en las semanas del año eclesiástico activo.
class UnitPointsHistoryView extends ConsumerWidget {
  const UnitPointsHistoryView({super.key, required this.unit});

  final Unit unit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final clubAsync = ref.watch(clubContextProvider);
    final yearName = yearAsync.maybeWhen(
      data: (year) => year?.name,
      orElse: () => null,
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'units.detail.points_history_screen_title'.tr(),
        subtitle: yearName,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            if (yearAsync.isLoading || clubAsync.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final year = yearAsync.valueOrNull;
            if (yearAsync.hasError || year == null) {
              return SacEmptyState(
                icon: HugeIcons.strokeRoundedCalendar01,
                title: 'units.detail.points_history_no_year'.tr(),
                actionLabel: yearAsync.hasError ? 'common.retry'.tr() : null,
                onAction: yearAsync.hasError
                    ? () => ref.invalidate(currentEcclesiasticalYearProvider)
                    : null,
              );
            }

            final ctx = clubAsync.valueOrNull;
            if (clubAsync.hasError || ctx == null) {
              return SacEmptyState(
                icon: HugeIcons.strokeRoundedAlertDiamond,
                title: 'units.form.club_context_error'.tr(),
                actionLabel: 'common.retry'.tr(),
                onAction: () => ref.invalidate(clubContextProvider),
              );
            }

            return _HistoryBody(
              clubId: ctx.clubId,
              unitId: unit.id,
              year: year,
            );
          },
        ),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({
    required this.clubId,
    required this.unitId,
    required this.year,
  });

  final int clubId;
  final int unitId;
  final EcclesiasticalYearModel year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = UnitPointsHistoryQuery(clubId: clubId, unitId: unitId);
    final recordsAsync = ref.watch(unitPointsHistoryProvider(query));

    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => SacEmptyState(
        icon: HugeIcons.strokeRoundedAlertDiamond,
        title: error.toString().replaceFirst('Exception: ', ''),
        actionLabel: 'common.retry'.tr(),
        onAction: () => ref.invalidate(unitPointsHistoryProvider(query)),
      ),
      data: (records) {
        final weeks = weeklyPointsInRange(
          records: records,
          rangeStart: year.startDate,
          rangeEnd: year.endDate,
        );
        if (weeks.isEmpty) {
          return SacEmptyState(
            icon: HugeIcons.strokeRoundedCalendar01,
            title: 'units.detail.points_history_empty'.tr(),
          );
        }

        final locale = context.locale.toString();
        final dateFormat = DateFormat.MMMd(locale);

        return ListView.separated(
          padding: SacTopBar.paddingBelowBar(
            context,
            const EdgeInsets.fromLTRB(16, 12, 16, 28),
          ),
          itemCount: weeks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final week = weeks[index];
            return _WeekCard(
              week: week,
              rangeLabel: 'units.detail.week_range_label'.tr(
                namedArgs: {
                  'start': dateFormat.format(week.startDate),
                  'end': dateFormat.format(week.endDate),
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    required this.week,
    required this.rangeLabel,
  });

  final WeekPointsSnapshot week;
  final String rangeLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context).color;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: c.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'units.detail.points_history_week'.tr(
              namedArgs: {'week': '${week.week}'},
            ),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            rangeLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          for (final record in week.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      record.fullName.isEmpty ? '—' : record.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: c.text,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'units.list.points'.tr(
                      namedArgs: {'points': '${record.points}'},
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: record.points > 0 ? accent : c.textTertiary,
                          fontWeight: FontWeight.w700,
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
