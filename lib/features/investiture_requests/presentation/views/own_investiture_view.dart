import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/own_investiture_selection.dart';
import '../widgets/own_investiture_card.dart';

/// «Mi investidura»: el estado de la persona en cada clase, con los textos
/// cerrados del plan funcional. Es el destino de las notificaciones de
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('investiture_requests.own.title'),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            final history = historyAsync.valueOrNull;
            if (history == null) {
              if (historyAsync.hasError) {
                return Padding(
                  padding:
                      EdgeInsets.only(top: SacTopBar.frostedInset(context)),
                  child: SacEmptyState(
                    title: tr('investiture_requests.own.load_error_title'),
                    icon: HugeIcons.strokeRoundedAlert02,
                    actionLabel: tr('common.retry'),
                    actionIcon: HugeIcons.strokeRoundedRefresh,
                    actionVariant: SacButtonVariant.outline,
                    onAction: () =>
                        ref.invalidate(ownInvestitureHistoryProvider),
                  ),
                );
              }
              return const Center(child: SacLoading());
            }

            final entries = sortOwnEntries(history);
            return RefreshIndicator(
              color: SacAccent.of(context).color,
              onRefresh: refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: SacTopBar.paddingBelowBar(
                  context,
                  const EdgeInsets.fromLTRB(16, 16, 16, 32),
                ),
                children: [
                  if (entries.isEmpty) ...[
                    const SizedBox(height: 48),
                    SacEmptyState(
                      title: tr('investiture_requests.own.empty_title'),
                      body: tr('investiture_requests.own.empty_body'),
                      icon: HugeIcons.strokeRoundedMedal01,
                    ),
                  ] else
                    for (final entry in entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OwnInvestitureEntryCard(entry: entry),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
