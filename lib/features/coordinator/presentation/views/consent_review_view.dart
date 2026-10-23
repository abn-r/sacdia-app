import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../members/presentation/views/consent_verification_view.dart';
import '../../../members/presentation/widgets/join_request_card.dart';
import '../../domain/entities/consent_pending_queue.dart';
import '../providers/consent_review_providers.dart';

/// "Fichas por verificar": las fichas de consentimiento de menores que esperan
/// verificación en las secciones que cubre el coordinador (`consent:verify`).
///
/// Solo verifica: no hay aprobar ni rechazar (eso es de un director). La fila
/// abre la verificación con `canApprove: false`, que manda `approve: false`.
///
/// Una sola cola de todas las secciones que cubre el coordinador, de la ficha
/// más antigua a la más nueva (ver [ConsentReviewNotifier]); este widget pinta
/// el total, el resumen por sección y "Cargar más".
class ConsentReviewView extends ConsumerWidget {
  const ConsentReviewView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(consentReviewProvider);
    ref.invalidate(consentPendingCountProvider);
    try {
      await ref.read(consentReviewProvider.future);
    } catch (_) {
      // El error se pinta en la vista.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final async = ref.watch(consentReviewProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'coordinator.consent_review.title'.tr(),
        titleIcon: HugeIcon(
          icon: HugeIcons.strokeRoundedFileVerified,
          size: 22,
          color: SacAccent.of(context).color,
        ),
        actions: [
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: 'coordinator.consent_review.refresh_tooltip'.tr(),
              onPressed: async.isLoading ? null : () => _refresh(ref),
              icon: HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh,
                size: 18,
                color: c.textTertiary,
              ),
            ),
          ),
        ],
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => SafeArea(
            child: async.when(
              loading: () => const Center(child: SacLoading()),
              error: (_, __) => _LoadError(onRetry: () => _refresh(ref)),
              data: (state) => _Queue(
                state: state,
                onRefresh: () => _refresh(ref),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Queue extends ConsumerWidget {
  const _Queue({required this.state, required this.onRefresh});

  final ConsentReviewState state;
  final Future<void> Function() onRefresh;

  /// Verifica la ficha. `pop(false)` = verificada (no aprobada): sale de la
  /// lista. Volver atrás (`null`) la deja donde está.
  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ConsentPendingItem item,
  ) async {
    final verified = await Navigator.push<bool>(
      context,
      SacSharedAxisRoute<bool>(
        builder: (_) => ConsentVerificationView(
          request: item.request,
          // Un coordinador solo verifica: nunca se manda `approve: true`.
          canApprove: false,
        ),
      ),
    );
    if (verified != null) {
      ref.read(consentReviewProvider.notifier).removeRequest(
            item.assignmentId,
          );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hPad = Responsive.horizontalPadding(context);
    final notifier = ref.read(consentReviewProvider.notifier);

    return RefreshIndicator(
      color: SacAccent.of(context).color,
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
        children: _content(context, ref, notifier),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    ConsentReviewNotifier notifier,
  ) {
    switch (state.access) {
      case ConsentQueueAccess.noSections:
        return [
          SacEmptyState(
            icon: HugeIcons.strokeRoundedBuilding04,
            title: 'coordinator.consent_review.no_sections_title'.tr(),
            body: 'coordinator.consent_review.no_sections_subtitle'.tr(),
          ),
        ];
      case ConsentQueueAccess.denied:
        return [
          SacEmptyState(
            icon: HugeIcons.strokeRoundedLockKey,
            title: 'coordinator.consent_review.denied_title'.tr(),
            body: 'coordinator.consent_review.denied_subtitle'.tr(),
          ),
        ];
      case ConsentQueueAccess.granted:
        break;
    }

    // Lista vacía pero con fichas por traer (se verificaron todas las cargadas):
    // no es una cola vacía, se vuelve a pedir desde el principio.
    if (state.items.isEmpty && state.hasMore) {
      return [_ReloadQueue(state: state)];
    }

    if (state.items.isEmpty) {
      return [
        SacEmptyState(
          icon: HugeIcons.strokeRoundedFileVerified,
          title: 'coordinator.consent_review.empty_title'.tr(),
          body: 'coordinator.consent_review.empty_subtitle'.tr(),
        ),
      ];
    }

    return [
      _Summary(state: state),
      for (final item in state.items) ...[
        JoinRequestCard(
          request: item.request,
          caption: item.caption,
          onTap: () => _open(context, ref, item),
          onVerify: () => _open(context, ref, item),
        ),
        const SizedBox(height: 6),
      ],
      if (state.loadMoreFailed)
        _Note(
          icon: HugeIcons.strokeRoundedAlert02,
          text: 'coordinator.consent_review.load_more_failed'.tr(),
        ),
      if (state.hasMore) ...[
        const SizedBox(height: 8),
        SacButton.primary(
          text: 'coordinator.consent_review.load_more'.tr(),
          icon: HugeIcons.strokeRoundedArrowDown01,
          isLoading: state.loadingMore,
          onPressed: notifier.loadMore,
        ),
      ],
    ];
  }
}

/// La lista quedó vacía pero el servidor aún tiene fichas: pide la primera
/// página una vez al aparecer y, si no llega nada o falla, deja "Cargar más".
class _ReloadQueue extends ConsumerStatefulWidget {
  const _ReloadQueue({required this.state});

  final ConsentReviewState state;

  @override
  ConsumerState<_ReloadQueue> createState() => _ReloadQueueState();
}

class _ReloadQueueState extends ConsumerState<_ReloadQueue> {
  @override
  void initState() {
    super.initState();
    // Una sola vez: si la página vuelve vacía, queda el botón (sin bucle).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(consentReviewProvider.notifier).loadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Column(
      children: [
        _Summary(state: state),
        if (state.loadMoreFailed)
          _Note(
            icon: HugeIcons.strokeRoundedAlert02,
            text: 'coordinator.consent_review.load_more_failed'.tr(),
          ),
        const SizedBox(height: 8),
        SacButton.primary(
          text: 'coordinator.consent_review.load_more'.tr(),
          icon: HugeIcons.strokeRoundedArrowDown01,
          isLoading: state.loadingMore,
          onPressed: ref.read(consentReviewProvider.notifier).loadMore,
        ),
      ],
    );
  }
}

String _formsLabel(int count) => (count == 1
        ? 'coordinator.consent_review.forms_one'
        : 'coordinator.consent_review.forms_other')
    .tr(namedArgs: {'count': count.toString()});

/// El total de la cola y cuántas fichas esperan en cada sección.
class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final ConsentReviewState state;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formsLabel(state.total),
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          if (state.bySection.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'coordinator.consent_review.by_section'.tr(),
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            for (final section in state.bySection)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(color: c.text),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formsLabel(section.pendingConsentCount),
                      style: textTheme.labelMedium
                          ?.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final HugeIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 16, color: c.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: c.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SacEmptyState(
      icon: HugeIcons.strokeRoundedAlert02,
      title: 'coordinator.consent_review.load_error'.tr(),
      actionLabel: 'coordinator.consent_review.retry'.tr(),
      actionIcon: HugeIcons.strokeRoundedRefresh,
      onAction: onRetry,
    );
  }
}
