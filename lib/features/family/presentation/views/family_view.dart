import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_empty_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../domain/entities/dependent.dart';
import '../family_error_messages.dart';
import '../providers/family_providers.dart';
import '../widgets/dependent_card.dart';
import '../widgets/profile_switcher_sheet.dart';

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
        error: (error, _) => _ErrorState(
          message: familyErrorMessage(error),
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

class _ListBody extends ConsumerWidget {
  const _ListBody({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
      children: [
        for (final dependent in family.dependents)
          DependentCard(
            key: ValueKey(dependent.userId),
            dependent: dependent,
            onOpen: () =>
                context.push(RouteNames.familyDetailPath(dependent.userId)),
            onViewAs: () => switchToDependent(context, ref, dependent),
          ),
        const SizedBox(height: 4),
        _AddMinorAction(family: family),
        const SizedBox(height: 12),
        const _HaveCodeAction(),
        if (!family.canAddMore)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'family.limit_reached'.tr(
                namedArgs: {'max': '${family.maxDependents}'},
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context) {
    // Dentro de un scroll para que el pull-to-refresh funcione también vacío.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SacEmptyState(
                icon: HugeIcons.strokeRoundedUserGroup,
                title: 'family.empty.title'.tr(),
                body: 'family.empty.body'.tr(),
                actionLabel: family.canAddMore ? 'family.add_cta'.tr() : null,
                onAction: family.canAddMore
                    ? () => context.push(RouteNames.familyAdd)
                    : null,
                actionIcon: HugeIcons.strokeRoundedUserAdd01,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: _HaveCodeAction(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddMinorAction extends StatelessWidget {
  const _AddMinorAction({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context) {
    return SacButton.primary(
      text: 'family.add_cta'.tr(),
      icon: HugeIcons.strokeRoundedUserAdd01,
      // Deshabilitado en el máximo: el servidor sigue siendo la autoridad.
      onPressed:
          family.canAddMore ? () => context.push(RouteNames.familyAdd) : null,
    );
  }
}

/// "Tengo un código de vinculación": canjear un código de segundo tutor o de
/// reclamo del director (FP-62).
class _HaveCodeAction extends StatelessWidget {
  const _HaveCodeAction();

  @override
  Widget build(BuildContext context) {
    return SacButton.ghost(
      text: 'family.have_code'.tr(),
      icon: HugeIcons.strokeRoundedKey01,
      onPressed: () => context.push(RouteNames.familyLink),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SacButton.outline(text: 'common.retry'.tr(), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
