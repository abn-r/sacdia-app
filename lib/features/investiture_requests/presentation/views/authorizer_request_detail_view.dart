import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_dialog.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../data/investiture_request_error_keys.dart';
import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/investiture_resolution.dart';
import '../../domain/entities/person_status.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/authorizer_decisions.dart';
import '../utils/investiture_dates.dart';
import '../widgets/decision_sheet.dart';
import '../widgets/investiture_banner.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_person_row.dart';
import '../widgets/investiture_section_label.dart';
import '../widgets/resolution_summary.dart';

const _i18n = 'investiture_requests.authorizer';

/// Por qué el backend dejó de aceptar decisiones sobre la solicitud.
enum _ClosedReason { window, year }

/// Detalle de una solicitud para el autorizador: decide persona por persona
/// (investir con comentario opcional, o rechazar con motivo) y confirma todo
/// junto. El motivo humano de un rechazo nunca se muestra aquí.
class AuthorizerRequestDetailView extends ConsumerStatefulWidget {
  const AuthorizerRequestDetailView({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<AuthorizerRequestDetailView> createState() =>
      _AuthorizerRequestDetailViewState();
}

class _AuthorizerRequestDetailViewState
    extends ConsumerState<AuthorizerRequestDetailView> {
  final Map<String, DecisionChoice> _decisions = {};
  InvestitureResolution? _summary;
  _ClosedReason? _closed;

  String get _requestId => widget.requestId;

  Future<void> _refresh() async {
    ref.invalidate(authorizerRequestProvider(_requestId));
    try {
      await ref.read(authorizerRequestProvider(_requestId).future);
    } catch (_) {
      // El error se pinta desde el estado del provider.
    }
  }

  Future<void> _decide(RequestPerson person) async {
    final choice = await showDecisionSheet(
      context,
      personName: person.userName?.trim().isNotEmpty ?? false
          ? person.userName!.trim()
          : tr('investiture_requests.section.unnamed_person'),
      className: person.className,
      current: _decisions[person.personId],
    );
    if (choice == null || !mounted) return;
    setState(() {
      if (choice is ClearChoice) {
        _decisions.remove(person.personId);
      } else {
        _decisions[person.personId] = choice;
      }
    });
  }

  Future<void> _confirm(List<RequestPerson> decided) async {
    final invest = <InvestDecision>[];
    final reject = <RejectDecision>[];
    for (final person in decided) {
      switch (_decisions[person.personId]) {
        case InvestChoice(:final comment):
          invest
              .add(InvestDecision(personId: person.personId, comment: comment));
        case RejectChoice(:final reason):
          reject.add(RejectDecision(personId: person.personId, reason: reason));
        case ClearChoice():
        case null:
          break;
      }
    }
    if (invest.isEmpty && reject.isEmpty) return;

    final confirmed = await SacDialog.show(
      context,
      title: tr('$_i18n.confirm_title'),
      content: tr(
        '$_i18n.confirm_body',
        namedArgs: {'invest': '${invest.length}', 'reject': '${reject.length}'},
      ),
      confirmLabel: tr('$_i18n.confirm_action'),
    );
    if (confirmed != true || !mounted) return;

    final notifier = ref.read(resolveNotifierProvider(_requestId).notifier);
    final ok = await notifier.submit(invest: invest, reject: reject);
    if (!mounted) return;

    final state = ref.read(resolveNotifierProvider(_requestId));
    if (ok) {
      setState(() {
        _decisions.clear();
        _summary = state.resolution;
      });
      return;
    }

    final message = state.errorMessage;
    final closed = _closedReasonOf(state.errorCode);
    if (closed != null) {
      setState(() {
        _closed = closed;
        _decisions.clear();
      });
    } else {
      SacSnackBar.show(
        context,
        message ?? tr('investiture_requests.errors.generic'),
        isError: true,
      );
      // La solicitud pudo cambiar (p. ej. otra persona ya resolvió): recarga.
      ref.invalidate(authorizerRequestProvider(_requestId));
    }
  }

  /// Cierre de ventana o de año según el código de negocio del error.
  _ClosedReason? _closedReasonOf(String? errorCode) => switch (errorCode) {
        investitureWindowClosedCode => _ClosedReason.window,
        investitureYearClosedCode => _ClosedReason.year,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final requestAsync = ref.watch(authorizerRequestProvider(_requestId));
    // Mantiene vivo el notifier mientras exista la pantalla.
    final busy = ref.watch(resolveNotifierProvider(_requestId)).isLoading;
    final request = requestAsync.valueOrNull;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(
        title: tr('$_i18n.detail_title'),
        backgroundColor: c.canvas,
        frosted: true,
      ),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) {
            if (request == null) {
              if (requestAsync.hasError) {
                return InvestitureMessageState(
                  title: tr('$_i18n.detail_load_error_title'),
                  onRetry: _refresh,
                );
              }
              return const Center(child: SacLoading());
            }
            return _body(context, request, busy: busy);
          },
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    InvestitureRequest request, {
    required bool busy,
  }) {
    final c = context.sac;
    final pending = request.pendingPeople;
    final resolved = request.people
        .where((p) => p.status != PersonStatus.pending)
        .toList(growable: false);
    final canDecide = _closed == null;
    final pendingIds = pending.map((p) => p.personId).toSet();
    final decided = pending
        .where((p) => p.canAuthorize && _decisions.containsKey(p.personId))
        .toList(growable: false);
    final showBar = canDecide && decided.isNotEmpty;

    return Stack(
      children: [
        RefreshIndicator(
          color: SacAccent.of(context).color,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: SacTopBar.paddingBelowBar(
              context,
              EdgeInsets.fromLTRB(16, 16, 16, 32 + (showBar ? 76.0 : 0)),
            ),
            children: [
              _Header(request: request),
              if (_closed != null) ...[
                const SizedBox(height: 12),
                InvestitureBanner(
                  text: tr(
                    _closed == _ClosedReason.window
                        ? '$_i18n.window_closed'
                        : '$_i18n.year_closed',
                  ),
                  tone: InvestitureBannerTone.caution,
                  icon: _closed == _ClosedReason.window
                      ? HugeIcons.strokeRoundedCalendarLock01
                      : HugeIcons.strokeRoundedLockKey,
                ),
              ],
              if (_summary != null) ...[
                const SizedBox(height: 12),
                ResolutionSummary(
                  resolution: _summary!,
                  request: request,
                  onDismiss: () => setState(() => _summary = null),
                ),
              ],
              if (pending.isNotEmpty) ...[
                const SizedBox(height: 20),
                InvestitureSectionLabel(
                  title: tr('$_i18n.pending_title'),
                  count: pending.length,
                ),
                const SizedBox(height: 10),
                for (final person in pending)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PendingRow(
                      person: person,
                      decision: pendingIds.contains(person.personId)
                          ? _decisions[person.personId]
                          : null,
                      interactive: canDecide && person.canAuthorize && !busy,
                      onTap: () => _decide(person),
                    ),
                  ),
              ],
              if (resolved.isNotEmpty) ...[
                const SizedBox(height: 20),
                InvestitureSectionLabel(
                  title: tr('$_i18n.resolved_title'),
                  count: resolved.length,
                ),
                const SizedBox(height: 10),
                for (final person in resolved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ResolvedRow(person: person),
                  ),
              ],
              if (pending.isEmpty && resolved.isEmpty) ...[
                const SizedBox(height: 32),
                Text(
                  tr('$_i18n.no_people'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: c.ink500),
                ),
              ],
            ],
          ),
        ),
        if (showBar)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: c.canvas,
                border: Border(top: BorderSide(color: c.ink150)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: SacButton.primary(
                    text: tr(
                      '$_i18n.confirm_cta',
                      namedArgs: {'count': '${decided.length}'},
                    ),
                    icon: HugeIcons.strokeRoundedMedal01,
                    isEnabled: !busy,
                    isLoading: busy,
                    onPressed: () => _confirm(decided),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Cabecera: club, sección y distrito de la solicitud.
class _Header extends StatelessWidget {
  const _Header({required this.request});

  final InvestitureRequest request;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final club = request.clubName?.trim();
    final lines = [
      if (request.sectionName != null && request.sectionName!.isNotEmpty)
        request.sectionName!,
      if (request.districtName != null && request.districtName!.isNotEmpty)
        tr('$_i18n.district', namedArgs: {'name': request.districtName!}),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.paper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.ink150),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            club == null || club.isEmpty ? tr('$_i18n.club_fallback') : club,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c.ink900,
                ),
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              lines.join(' · '),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: c.ink500),
            ),
          ],
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({
    required this.person,
    required this.decision,
    required this.interactive,
    required this.onTap,
  });

  final RequestPerson person;
  final DecisionChoice? decision;
  final bool interactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = person.userName?.trim().isNotEmpty ?? false
        ? person.userName!.trim()
        : tr('investiture_requests.section.unnamed_person');
    final date = tr(
      'investiture_requests.section.pending_date',
      namedArgs: {
        'date': formatInvestitureDate(context, person.investitureDate)
      },
    );

    final Widget status = switch (decision) {
      InvestChoice() => SacBadge.success(
          label: tr('$_i18n.decision_invest'),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
      RejectChoice() => SacBadge.error(
          label: tr('$_i18n.decision_reject'),
          icon: HugeIcons.strokeRoundedCancelCircle,
        ),
      _ => SacBadge.warning(
          label: tr(
            person.canAuthorize ? '$_i18n.undecided' : '$_i18n.waiting',
          ),
          icon: HugeIcons.strokeRoundedClock01,
        ),
    };

    final choice = decision;
    final note = switch (choice) {
      InvestChoice(:final comment) when comment != null => comment,
      RejectChoice(:final reason) => reason,
      _ => null,
    };

    return InvestiturePersonRow(
      name: name,
      className: person.className,
      detail:
          [if (person.className != null) person.className!, date].join(' · '),
      onTap: interactive ? onTap : null,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              status,
              const Spacer(),
              if (interactive)
                SacButton(
                  text: tr(
                    decision == null ? '$_i18n.decide' : '$_i18n.change',
                  ),
                  variant: SacButtonVariant.outline,
                  size: SacButtonSize.small,
                  minHeight: 44,
                  icon: HugeIcons.strokeRoundedEdit02,
                  onPressed: onTap,
                ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.ink600,
                    fontStyle: FontStyle.italic,
                    height: 1.35,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ResolvedRow extends StatelessWidget {
  const _ResolvedRow({required this.person});

  final RequestPerson person;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = person.userName?.trim().isNotEmpty ?? false
        ? person.userName!.trim()
        : tr('investiture_requests.section.unnamed_person');

    final SacBadge? badge = switch (person.status) {
      PersonStatus.invested => SacBadge.success(
          label: tr('investiture_requests.history.status_invested'),
          icon: HugeIcons.strokeRoundedCheckmarkCircle02,
        ),
      PersonStatus.rejectedByPerson || PersonStatus.rejected => SacBadge.error(
          label: tr('investiture_requests.history.status_not_invested'),
          icon: HugeIcons.strokeRoundedCancelCircle,
        ),
      PersonStatus.rejectedBySystem => SacBadge.error(
          label: tr('$_i18n.status_rejected_by_system'),
          icon: HugeIcons.strokeRoundedAlert02,
        ),
      PersonStatus.removed => SacBadge(
          label: tr('$_i18n.status_removed'),
          variant: SacBadgeVariant.neutral,
          icon: HugeIcons.strokeRoundedInformationCircle,
        ),
      PersonStatus.closedYear => SacBadge.warning(
          label: tr('investiture_requests.history.status_closed_year'),
          icon: HugeIcons.strokeRoundedCalendar03,
        ),
      _ => null,
    };

    // El texto largo solo existe cuando decidió el sistema; el motivo humano
    // de un rechazo no se lee nunca en esta pantalla.
    final systemNote = person.status == PersonStatus.rejectedBySystem
        ? person.systemReason?.trim()
        : null;
    final decidedBy = person.resolvedByName?.trim();

    return InvestiturePersonRow(
      name: name,
      className: person.className,
      detail: [
        if (person.className != null) person.className!,
        formatInvestitureDate(context, person.investitureDate),
      ].join(' · '),
      footer: badge == null && systemNote == null && decidedBy == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (badge != null) badge,
                if (decidedBy != null && decidedBy.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    tr('$_i18n.decided_by', namedArgs: {'name': decidedBy}),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.ink500),
                  ),
                ],
                if (systemNote != null && systemNote.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    systemNote,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.ink600,
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
    );
  }
}
