import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/responsive.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_empty_state.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../../members/domain/entities/join_request.dart';
import '../../../members/presentation/views/consent_verification_view.dart';
import '../../../members/presentation/widgets/join_request_card.dart';
import '../providers/consent_review_providers.dart';
import '../providers/coordinator_providers.dart';

/// "Fichas por verificar": las fichas de consentimiento de menores que esperan
/// verificación en las secciones que cubre el coordinador (`consent:verify`).
///
/// Solo verifica: no hay aprobar ni rechazar (eso es de un director). La fila
/// abre la verificación con `canApprove: false`, que manda `approve: false`.
///
/// Las secciones se consultan por páginas (ver [ConsentReviewNotifier]); este
/// widget solo pinta el avance y ofrece "Revisar más secciones".
class ConsentReviewView extends ConsumerWidget {
  const ConsentReviewView({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(coordinatorScopeProvider);
    ref.invalidate(consentReviewProvider);
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
    JoinRequest request,
  ) async {
    final verified = await Navigator.push<bool>(
      context,
      SacSharedAxisRoute<bool>(
        builder: (_) => ConsentVerificationView(
          request: request,
          // Un coordinador solo verifica: nunca se manda `approve: true`.
          canApprove: false,
        ),
      ),
    );
    if (verified != null) {
      ref.read(consentReviewProvider.notifier).removeRequest(
            request.assignmentId,
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
        children: [
          if (state.entries.isEmpty)
            SacEmptyState(
              icon: HugeIcons.strokeRoundedFileVerified,
              title: 'coordinator.consent_review.empty_title'.tr(),
              body: (state.hasMore
                      ? 'coordinator.consent_review.empty_more_subtitle'
                      : 'coordinator.consent_review.empty_subtitle')
                  .tr(),
            ),
          for (final entry in state.entries) ...[
            _SectionHeader(entry: entry),
            for (final request in entry.requests) ...[
              JoinRequestCard(
                request: request,
                onTap: () => _open(context, ref, request),
                onVerify: () => _open(context, ref, request),
              ),
              const SizedBox(height: 6),
            ],
            const SizedBox(height: 10),
          ],
          if (state.droppedSectionIds.isNotEmpty)
            _Note(
              icon: HugeIcons.strokeRoundedLockKey,
              text: (state.droppedSectionIds.length == 1
                      ? 'coordinator.consent_review.dropped_one'
                      : 'coordinator.consent_review.dropped_other')
                  .tr(
                namedArgs: {
                  'count': state.droppedSectionIds.length.toString(),
                },
              ),
            ),
          if (state.failedSectionIds.isNotEmpty) ...[
            _Note(
              icon: HugeIcons.strokeRoundedAlert02,
              text: (state.failedSectionIds.length == 1
                      ? 'coordinator.consent_review.failed_one'
                      : 'coordinator.consent_review.failed_other')
                  .tr(
                namedArgs: {
                  'count': state.failedSectionIds.length.toString(),
                },
              ),
            ),
            const SizedBox(height: 8),
            SacButton.outline(
              text: 'coordinator.consent_review.retry_failed'.tr(),
              icon: HugeIcons.strokeRoundedRefresh,
              isLoading: state.loadingMore,
              onPressed: notifier.retryFailed,
            ),
            const SizedBox(height: 12),
          ],
          if (state.sections.isNotEmpty) _Progress(state: state),
          if (state.hasMore) ...[
            const SizedBox(height: 8),
            SacButton.primary(
              text: 'coordinator.consent_review.load_more'.tr(),
              icon: HugeIcons.strokeRoundedArrowDown01,
              isLoading: state.loadingMore,
              onPressed: notifier.loadMore,
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.entry});

  final ConsentReviewSection entry;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final section = entry.section;
    final club = section.clubName?.trim();
    final label = club == null || club.isEmpty
        ? section.displayName
        : '$club · ${section.displayName}';
    final count = entry.requests.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            (count == 1
                    ? 'coordinator.consent_review.forms_one'
                    : 'coordinator.consent_review.forms_other')
                .tr(namedArgs: {'count': count.toString()}),
            style: TextStyle(fontSize: 12, color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.state});

  final ConsentReviewState state;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'coordinator.consent_review.progress'.tr(
          namedArgs: {
            'checked': state.checkedCount.toString(),
            'total': state.sections.length.toString(),
          },
        ),
        style: TextStyle(fontSize: 12, color: context.sac.textSecondary),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final List<List<dynamic>> icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: c.textSecondary),
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
