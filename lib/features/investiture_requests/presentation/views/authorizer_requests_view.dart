import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/authorization/access_subject.dart';
import '../../../../core/authorization/screen_catalog.dart';
import '../../../../core/config/route_names.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../../providers/catalogs_provider.dart';
import '../../../dashboard/presentation/widgets/clubless_home_header.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/investiture_request_error_keys.dart';
import '../../domain/entities/investiture_request.dart';
import '../providers/investiture_requests_providers.dart';
import '../utils/investiture_dates.dart';
import '../widgets/investiture_message_state.dart';
import '../widgets/investiture_rows.dart';
import '../widgets/investiture_skeleton.dart';

const _i18n = 'investiture_requests.authorizer';

/// Solicitudes de investidura que el usuario puede autorizar (pastor del
/// distrito, director o subdirector del Campo). Es el inicio del pastor sin
/// club y una entrada del acceso rápido de `director-lf`/`assistant-lf`.
///
/// Como inicio ([asHome], lo pasa `DashboardView`) lleva el encabezado de
/// saludo del dashboard en lugar de la barra superior; como ruta normal
/// conserva la barra con su flecha.
class AuthorizerRequestsView extends ConsumerWidget {
  const AuthorizerRequestsView({super.key, this.asHome = false});

  /// Se dibuja como inicio del pastor sin club (saludo + título, sin barra).
  final bool asHome;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final user = ref.watch(authNotifierProvider.select((v) => v.value));
    final allowed = canViewScreen(
      subjectFromUser(user),
      'app-investiture-authorizer',
    );
    final yearAsync = ref.watch(currentEcclesiasticalYearProvider);
    final year = yearAsync.value;
    final header =
        asHome ? ClubLessHomeHeader(sectionTitle: tr('$_i18n.title')) : null;

    final Widget body;
    if (!allowed) {
      body = _withHeader(
        header,
        InvestitureMessageState(
          title: tr('$_i18n.restricted_title'),
          body: tr('$_i18n.restricted_body'),
          icon: HugeIcons.strokeRoundedLockKey,
        ),
      );
    } else if (year == null) {
      if (yearAsync.hasError) {
        body = _withHeader(
          header,
          InvestitureMessageState.loadError(
            title: tr('$_i18n.load_error_title'),
            error: yearAsync.error,
            onRetry: () => ref.invalidate(currentEcclesiasticalYearProvider),
          ),
        );
      } else {
        body = _withHeader(
          header,
          yearAsync.isLoading
              ? const InvestitureListSkeleton()
              : InvestitureMessageState(
                  title: tr('$_i18n.no_year_title'),
                  body: tr('$_i18n.no_year_body'),
                  icon: HugeIcons.strokeRoundedCalendar03,
                ),
        );
      }
    } else {
      body = _RequestsBody(
        yearId: year.ecclesiasticalYearId,
        yearName: year.name.trim(),
        header: header,
      );
    }

    if (asHome) {
      return Scaffold(
        backgroundColor: c.canvas,
        body: SafeArea(
          bottom: false,
          // Sin barra superior: los scrolls no reservan hueco para ella.
          child: SacFrostedInsetOverride(inset: 0, child: body),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: c.canvas,
      appBar: SacTopBar(title: '', backgroundColor: c.canvas, frosted: true),
      body: SacFrostedVeil(child: body),
    );
  }
}

/// El saludo del inicio encima de un estado que no hace scroll.
Widget _withHeader(Widget? header, Widget child) => header == null
    ? child
    : Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, Expanded(child: child)],
      );

class _RequestsBody extends ConsumerWidget {
  const _RequestsBody({
    required this.yearId,
    required this.yearName,
    this.header,
  });

  final int yearId;
  final String yearName;

  /// Saludo del inicio: primer elemento del scroll y ya lleva el título.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final requestsAsync = ref.watch(authorizerRequestsProvider(yearId));

    Future<void> refresh() async {
      ref.invalidate(authorizerRequestsProvider(yearId));
      try {
        await ref.read(authorizerRequestsProvider(yearId).future);
      } catch (_) {
        // El error se pinta desde el estado del provider.
      }
    }

    final requests = requestsAsync.value;
    if (requests == null) {
      if (requestsAsync.hasError) {
        final error = requestsAsync.error;
        // Pastor sin distritos asignados: el backend responde 403 al listado.
        if (error is Failure && error.errorCode == investitureForbiddenCode) {
          return _scrollable(
            context,
            refresh,
            [
              if (header != null) header!,
              const SizedBox(height: 48),
              SacEmptyState(
                title: tr('$_i18n.no_districts_title'),
                body: tr('$_i18n.no_districts_body'),
                icon: HugeIcons.strokeRoundedChurch,
              ),
            ],
          );
        }
        return _withHeader(
          header,
          InvestitureMessageState.loadError(
            title: tr('$_i18n.load_error_title'),
            error: error,
            onRetry: refresh,
          ),
        );
      }
      return _withHeader(header, const InvestitureListSkeleton());
    }

    final waiting = _sorted(requests.where(_hasPeopleWaiting));
    final resolved = _sorted(requests.where((r) => !_hasPeopleWaiting(r)));
    final waitingPeople = waiting.fold<int>(0, (sum, r) => sum + _pending(r));
    final clubs =
        waiting.map((r) => r.clubId?.toString() ?? r.requestId).toSet().length;
    final districts = {
      for (final r in requests)
        if (r.districtName != null && r.districtName!.trim().isNotEmpty)
          r.districtName!.trim(),
    };
    final subtitle = [
      if (districts.length == 1)
        tr('$_i18n.district', namedArgs: {'name': districts.first}),
      if (yearName.isNotEmpty) yearName,
    ].join(' · ');

    return _scrollable(context, refresh, [
      if (header != null)
        header!
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Semantics(
            header: true,
            child: Text(
              tr('$_i18n.title'),
              style: TextStyle(
                fontSize: SacFontSize.displayMedium,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: c.text,
              ),
            ),
          ),
        ),
      if (subtitle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: SacFontSize.titleSmall,
              color: c.textSecondary,
            ),
          ),
        ),
      if (requests.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 48),
          child: SacEmptyState(
            title: tr('$_i18n.empty_title'),
            body: tr('$_i18n.empty_body'),
            icon: HugeIcons.strokeRoundedMedal01,
          ),
        )
      else ...[
        _Summary(
          people: waitingPeople,
          clubs: clubs,
          nearest: waiting.isEmpty ? null : waiting.first,
        ),
        if (waiting.isNotEmpty)
          SacGroupedSection(
            key: const ValueKey('authorizer-group-waiting'),
            label: tr('$_i18n.waiting_title'),
            children: [
              for (final r in waiting)
                _RequestRow(
                  request: r,
                  onTap: () => context.push(
                    RouteNames.investitureAuthorizeDetailPath(r.requestId),
                  ),
                ),
            ],
          ),
        if (resolved.isNotEmpty)
          SacGroupedSection(
            key: const ValueKey('authorizer-group-resolved'),
            label: tr('$_i18n.resolved_group_title'),
            children: [
              for (final r in resolved)
                _RequestRow(
                  request: r,
                  onTap: () => context.push(
                    RouteNames.investitureAuthorizeDetailPath(r.requestId),
                  ),
                ),
            ],
          ),
      ],
    ]);
  }

  Widget _scrollable(
    BuildContext context,
    Future<void> Function() refresh,
    List<Widget> children,
  ) {
    return RefreshIndicator(
      color: SacAccent.of(context).color,
      edgeOffset: SacTopBar.frostedInset(context),
      onRefresh: refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: SacTopBar.paddingBelowBar(
          context,
          const EdgeInsets.only(top: 4, bottom: 32),
        ),
        children: children,
      ),
    );
  }

  static int _pending(InvestitureRequest r) =>
      r.pendingCount ?? r.pendingPeople.length;

  static bool _hasPeopleWaiting(InvestitureRequest r) => _pending(r) > 0;

  /// Con personas en espera primero la fecha más próxima; sin fecha, al final.
  static List<InvestitureRequest> _sorted(Iterable<InvestitureRequest> items) {
    final list = items.toList();
    list.sort((a, b) {
      final dateA = a.earliestInvestitureDate;
      final dateB = b.earliestInvestitureDate;
      if (dateA != null && dateB != null) {
        final byDate = dateA.compareTo(dateB);
        if (byDate != 0) return byDate;
      } else if (dateA != null) {
        return -1;
      } else if (dateB != null) {
        return 1;
      }
      return (a.clubName ?? '').compareTo(b.clubName ?? '');
    });
    return list;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.people,
    required this.clubs,
    required this.nearest,
  });

  final int people;
  final int clubs;
  final InvestitureRequest? nearest;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final nearestDate = nearest?.earliestInvestitureDate;
    final nearestClub = nearest?.clubName?.trim();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: SacSummaryBox(
        color: c.surfaceVariant,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('$_i18n.summary.label'),
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                fontWeight: FontWeight.w600,
                color: c.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              key: const ValueKey('authorizer-summary-people'),
              TextSpan(
                children: [
                  TextSpan(
                    text: '$people',
                    style: TextStyle(
                      fontSize: SacFontSize.displayMedium,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: c.text,
                    ),
                  ),
                  if (people > 0)
                    TextSpan(
                      text: '  ·  ${'$_i18n.summary.in_clubs'.plural(clubs)}',
                      style: TextStyle(
                        fontSize: SacFontSize.bodyMedium,
                        color: c.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            if (people > 0 && nearestDate != null) ...[
              const SizedBox(height: 6),
              Text(
                tr(
                  '$_i18n.summary.nearest',
                  namedArgs: {
                    'date': formatInvestitureShortDay(context, nearestDate),
                    'club': nearestClub == null || nearestClub.isEmpty
                        ? tr('$_i18n.club_fallback')
                        : nearestClub,
                  },
                ),
                style: TextStyle(
                  fontSize: SacFontSize.bodySmall,
                  color: c.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.request, required this.onTap});

  final InvestitureRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final tint = investitureAccentTint(context);
    final pending = request.pendingCount ?? request.pendingPeople.length;
    final waiting = pending > 0;
    final club = request.clubName?.trim();
    final date = request.earliestInvestitureDate;
    final detail = [
      if (request.sectionName != null && request.sectionName!.isNotEmpty)
        request.sectionName!,
      if (date != null) formatInvestitureShortDay(context, date),
    ].join(' · ');

    Widget? chip;
    if (waiting) {
      chip = SacBadge.info(
        label: tr('$_i18n.pending_count', namedArgs: {'count': '$pending'}),
      );
    } else if (request.investedCount > 0) {
      chip = SacBadge.success(
        label: '$_i18n.invested_count'.plural(request.investedCount),
      );
    } else if (request.rejectedCount > 0) {
      chip = SacBadge(
        label: '$_i18n.rejected_count'.plural(request.rejectedCount),
        variant: SacBadgeVariant.neutral,
      );
    }

    return InvestitureRow(
      leading: InvestitureIconBadge(
        icon: waiting
            ? HugeIcons.strokeRoundedUserGroup
            : HugeIcons.strokeRoundedCheckmarkCircle02,
        background: waiting ? tint.background : c.surfaceVariant,
        foreground: waiting ? tint.foreground : c.textSecondary,
      ),
      title: club == null || club.isEmpty ? tr('$_i18n.club_fallback') : club,
      detail: detail,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chip != null) ...[
            Flexible(child: chip),
            const SizedBox(width: 4)
          ],
          const InvestitureChevron(),
        ],
      ),
      onTap: onTap,
    );
  }
}
