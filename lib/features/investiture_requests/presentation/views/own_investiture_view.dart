import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../classes/presentation/providers/classes_providers.dart';
import '../../domain/entities/own_investiture_entry.dart';
import '../../domain/entities/person_status.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import '../utils/own_investiture_selection.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_rows.dart';
import '../widgets/investiture_skeleton.dart';
import '../widgets/own_investiture_hero.dart';

const _i18n = 'investiture_requests.own';

/// «Mi investidura»: el estado de la clase actual como protagonista, con tres
/// pasos, y debajo todas mis clases. Es el destino de las notificaciones de
/// resultado para quien no es de la directiva.
class OwnInvestitureView extends ConsumerWidget {
  const OwnInvestitureView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final historyAsync = ref.watch(ownInvestitureHistoryProvider);

    Future<void> refresh() async {
      ref.invalidate(ownInvestitureHistoryProvider);
      try {
        await ref.read(ownInvestitureHistoryProvider.future);
      } catch (_) {
        // El error se pinta desde el estado del provider.
      }
    }

    final history = historyAsync.value;
    final Widget body;
    if (history == null) {
      body = historyAsync.hasError
          ? InvestitureMessageState.loadError(
              title: tr('$_i18n.load_error_title'),
              error: historyAsync.error,
              onRetry: () => ref.invalidate(ownInvestitureHistoryProvider),
            )
          : const InvestitureListSkeleton(rows: 3);
    } else {
      final entries = sortOwnEntries(history);
      body = RefreshIndicator(
        color: SacAccent.of(context).color,
        edgeOffset: SacTopBar.frostedInset(context),
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: SacTopBar.paddingBelowBar(
            context,
            const EdgeInsets.only(top: 4, bottom: 32),
          ),
          children: entries.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: SacEmptyState(
                      title: tr('$_i18n.empty_title'),
                      body: tr('$_i18n.empty_body'),
                      icon: HugeIcons.strokeRoundedMedal01,
                    ),
                  ),
                ]
              : _content(context, ref, entries),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('$_i18n.title'),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(child: body),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    List<OwnInvestitureEntry> entries,
  ) {
    final hero = heroEntry(entries)!;
    final next = hero.status == PersonStatus.invested
        ? nextEnrolledClass(
            ref.watch(userClassesProvider).value ?? const [],
            hero.classId,
          )
        : null;

    return [
      OwnInvestitureHero(entry: hero),
      if (next != null)
        InvestitureCard(
          key: const ValueKey('own-next-class'),
          children: [
            InvestitureRow(
              leading: InvestitureIconBadge(
                icon: HugeIcons.strokeRoundedStar,
                background: investitureAccentTint(context).background,
                foreground: investitureAccentTint(context).foreground,
              ),
              title: tr('$_i18n.next_class', namedArgs: {'name': next.name}),
              detail: tr('$_i18n.next_class_hint'),
              trailing: const InvestitureChevron(),
              onTap: () =>
                  context.push(RouteNames.classDetailPath('${next.id}')),
            ),
          ],
        ),
      SacGroupedSection(
        key: const ValueKey('own-classes'),
        label: tr('$_i18n.classes_title'),
        children: [for (final entry in entries) _ClassRow(entry: entry)],
      ),
    ];
  }
}

class _ClassRow extends ConsumerWidget {
  const _ClassRow({required this.entry});

  final OwnInvestitureEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ownEntryStyle(context, ref, entry);
    final year = ownEntryYearLabel(ref, entry);
    final className = entry.className?.trim().isNotEmpty ?? false
        ? entry.className!.trim()
        : tr('$_i18n.class_fallback');

    final String line = switch (entry.status) {
      PersonStatus.pending => tr(
          '$_i18n.row_pending_year',
          namedArgs: {
            'year': year,
            'date': formatInvestitureShortDay(context, entry.investitureDate),
          },
        ),
      PersonStatus.invested => [
          year,
          entry.resolvedByName?.trim(),
        ].where((p) => p != null && p.isNotEmpty).join(' · '),
      PersonStatus.removed => '$year · ${entry.personText?.trim() ?? ''}',
      PersonStatus.closedYear => year,
      _ => '$year · ${tr('$_i18n.row_rejected_detail')}',
    };

    final Widget? chip = switch (entry.status) {
      PersonStatus.pending => SacBadge.info(label: tr('$_i18n.chip_pending')),
      PersonStatus.invested =>
        SacBadge.success(label: tr('$_i18n.chip_invested')),
      PersonStatus.removed => null,
      _ => SacBadge(
          label: tr('$_i18n.chip_not_invested'),
          variant: SacBadgeVariant.neutral,
        ),
    };

    final tappable = entry.status == PersonStatus.pending ||
        entry.status == PersonStatus.invested;
    return InvestitureRow(
      leading: InvestitureIconBadge(
        icon: style.icon,
        background: style.container,
        foreground: style.onContainer,
      ),
      title: className,
      detail: line,
      detailMaxLines: 2,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip != null) Flexible(child: chip),
          if (tappable) ...[
            const SizedBox(width: 4),
            const InvestitureChevron(),
          ],
        ],
      ),
      onTap: tappable
          ? () => context.push(RouteNames.classDetailPath('${entry.classId}'))
          : null,
    );
  }
}
