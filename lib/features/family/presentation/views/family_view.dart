import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../../core/widgets/status_progress/status_progress.dart';
import '../../../majority_release/presentation/widgets/released_history_tile.dart';
import '../../domain/entities/dependent.dart';
import '../family_error_messages.dart';
import '../providers/family_providers.dart';
import '../widgets/family_row.dart';

/// "Mi familia": los menores a cargo del tutor (FP-57).
///
/// Solo se alcanza desde el perfil propio del tutor; mientras se actúa por un
/// menor el router redirige al inicio.
class FamilyView extends ConsumerWidget {
  const FamilyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final overview = ref.watch(dependentsProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: SacTopBar(
        title: 'family.title'.tr(),
        backgroundColor: c.background,
        foregroundColor: c.text,
      ),
      body: overview.when(
        loading: () => const Center(child: SacLoading()),
        error: (error, _) => SacErrorState(
          title: familyErrorMessage(error),
          onRetry: () => ref.invalidate(dependentsProvider),
        ),
        data: (family) => RefreshIndicator(
          color: SacAccent.of(context).color,
          onRefresh: () async {
            ref.invalidate(dependentsProvider);
            await ref.read(dependentsProvider.future).catchError(
                  (_) => const FamilyOverview(dependents: [], maxDependents: 0),
                );
          },
          child: family.dependents.isEmpty
              ? _EmptyBody(family: family)
              : _ListBody(family: family),
        ),
      ),
    );
  }
}

/// Minors whose signed consent form is still missing: the one thing the
/// guardian has to do.
List<DependentSummary> dependentsMissingForm(FamilyOverview family) => [
      for (final d in family.dependents)
        if (!d.frozen &&
            !d.guardianship.isVerified &&
            !d.guardianship.evidenceUploaded)
          d,
    ];

class _ListBody extends StatelessWidget {
  const _ListBody({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context) {
    final missing = dependentsMissingForm(family);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        if (missing.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: _MissingFormPanel(missing: missing),
          ),
        SacGroupedSection(
          label: 'family.list_title'.tr(),
          children: [
            for (final dependent in family.dependents)
              DependentRow(
                dependent: dependent,
                onTap: () =>
                    context.push(RouteNames.familyDetailPath(dependent.userId)),
              ),
          ],
        ),
        SacGroupedSection(
          label: 'family.add_group'.tr(),
          action: const SizedBox.shrink(),
          dividerIndent: 62,
          children: [
            _AddRow(family: family),
            const _CodeRow(),
          ],
        ),
        // Fase 4: personas liberadas al cumplir la mayoría de edad.
        const ReleasedHistoryTile(),
      ],
    );
  }
}

/// "Falta la ficha de Lucas": what the guardian has to do first.
class _MissingFormPanel extends StatelessWidget {
  const _MissingFormPanel({required this.missing});

  final List<DependentSummary> missing;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final first = missing.first;
    final single = missing.length == 1;
    final title = single
        ? 'family.todo.form_title'.tr(namedArgs: {'name': first.firstName})
        : 'family.todo.forms_title'
            .tr(namedArgs: {'count': '${missing.length}'});
    return SacStatePanel(
      key: const ValueKey('family-missing-form'),
      style: SacStatusStyle(
        kind: SacStatusKind.pending,
        container: c.warningContainer,
        onContainer: c.onWarningContainer,
        solid: c.warning,
        icon: HugeIcons.strokeRoundedFileEdit,
        label: title,
      ),
      title: title,
      message:
          (single ? 'family.todo.form_message' : 'family.todo.forms_message')
              .tr(),
      stepLabel: 'family.todo.open'.tr(namedArgs: {'name': first.firstName}),
      onTap: () => context.push(RouteNames.familyDetailPath(first.userId)),
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context) {
    return FamilyRow(
      key: const ValueKey('family-option-add'),
      leading: const FamilyRowIcon(HugeIcons.strokeRoundedUserAdd01),
      title: 'family.option.add_title'.tr(),
      subtitle: family.canAddMore
          ? 'family.option.spots_left'.plural(
              family.maxDependents - family.dependents.length,
            )
          : 'family.limit_reached'.tr(
              namedArgs: {'max': '${family.maxDependents}'},
            ),
      // At the limit: the server is still the authority.
      enabled: family.canAddMore,
      onTap: () => context.push(RouteNames.familyAdd),
    );
  }
}

/// Redeem a second-guardian or director claim code (FP-62).
class _CodeRow extends StatelessWidget {
  const _CodeRow();

  @override
  Widget build(BuildContext context) {
    return FamilyRow(
      key: const ValueKey('family-option-code'),
      leading: const FamilyRowIcon(HugeIcons.strokeRoundedKey01),
      title: 'family.option.code_title'.tr(),
      subtitle: 'family.option.code_subtitle'.tr(),
      onTap: () => context.push(RouteNames.familyLink),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);
    final theme = Theme.of(context);

    // Inside a scroll so pull-to-refresh also works while empty.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 24, bottom: 32),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.light,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              size: 32,
              color: accent.color,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                'family.empty.headline'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'family.empty.subline'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
        SacGroupedSection(
          label: 'family.add_group'.tr(),
          action: const SizedBox.shrink(),
          dividerIndent: 62,
          children: [
            if (family.canAddMore)
              FamilyRow(
                key: const ValueKey('family-option-add'),
                leading: const FamilyRowIcon(HugeIcons.strokeRoundedUserAdd01),
                title: 'family.option.add_title'.tr(),
                subtitle: 'family.option.add_subtitle'.tr(),
                onTap: () => context.push(RouteNames.familyAdd),
              ),
            const _CodeRow(),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'family.how.title'.tr().toUpperCase(),
                style: TextStyle(
                  fontSize: SacFontSize.labelSmall,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: 10),
              for (var i = 1; i <= 3; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 18,
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            fontWeight: FontWeight.w700,
                            color: accent.color,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'family.how.step$i'.tr(),
                          style: TextStyle(
                            fontSize: SacFontSize.bodyMedium,
                            height: 1.4,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        // Fase 4: personas liberadas al cumplir la mayoría de edad.
        const ReleasedHistoryTile(),
      ],
    );
  }
}
