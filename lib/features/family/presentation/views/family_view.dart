import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/class_tone.dart';
import '../../../../core/utils/icon_helper.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_error_state.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../majority_release/presentation/widgets/released_history_tile.dart';
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

class _ListBody extends ConsumerWidget {
  const _ListBody({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hPad = Responsive.horizontalPadding(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 32),
      children: [
        _SectionLabel(
          '${'family.list_title'.tr()} · ${family.dependents.length}',
        ),
        const SizedBox(height: 8),
        for (final dependent in family.dependents)
          DependentCard(
            key: ValueKey(dependent.userId),
            dependent: dependent,
            onOpen: () =>
                context.push(RouteNames.familyDetailPath(dependent.userId)),
            onViewAs: () => switchToDependent(context, ref, dependent),
          ),
        const SizedBox(height: 4),
        // Both ways in, side by side as bento tiles.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FamilyOptionTile(
                  key: const ValueKey('family-option-add'),
                  option: _FamilyOption.add(
                    context,
                    subtitle: family.canAddMore
                        ? 'family.option.spots_left'.plural(
                            family.maxDependents - family.dependents.length,
                          )
                        : 'family.limit_reached'.tr(
                            namedArgs: {'max': '${family.maxDependents}'},
                          ),
                    // At the limit: the server is still the authority.
                    enabled: family.canAddMore,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FamilyOptionTile(
                  key: const ValueKey('family-option-code'),
                  option: _FamilyOption.code(context),
                ),
              ),
            ],
          ),
        ),
        // Fase 4: personas liberadas al cumplir la mayoría de edad, colapsadas.
        const ReleasedHistoryTile(),
      ],
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.family});

  final FamilyOverview family;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hPad = Responsive.horizontalPadding(context);
    // Inside the family flow everything speaks the accent, like its buttons.
    final tone = ClassTone.of(context, SacAccent.of(context).color);
    final theme = Theme.of(context);

    // Inside a scroll so pull-to-refresh also works while empty.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(hPad, 24, hPad, 32),
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.container,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedUserGroup,
              size: 36,
              color: tone.onContainer,
            ),
          ),
        ),
        const SizedBox(height: 16),
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
          style: theme.textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 24),
        if (family.canAddMore) ...[
          _FamilyOptionRow(
            key: const ValueKey('family-option-add'),
            option: _FamilyOption.add(
              context,
              subtitle: 'family.option.add_subtitle'.tr(),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _FamilyOptionRow(
          key: const ValueKey('family-option-code'),
          option: _FamilyOption.code(context),
        ),
        const SizedBox(height: 28),
        _SectionLabel('family.how.title'.tr()),
        const SizedBox(height: 10),
        for (var i = 1; i <= 3; i++) ...[
          _HowStep(number: i, text: 'family.how.step$i'.tr(), tone: tone),
          if (i < 3) const SizedBox(height: 10),
        ],
        // Fase 4: personas liberadas al cumplir la mayoría de edad.
        const ReleasedHistoryTile(),
      ],
    );
  }
}

/// One way into the family: register a minor or redeem a code.
class _FamilyOption {
  const _FamilyOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tone,
    required this.onTap,
    this.enabled = true,
  });

  factory _FamilyOption.add(
    BuildContext context, {
    required String subtitle,
    bool enabled = true,
  }) =>
      _FamilyOption(
        title: 'family.option.add_title'.tr(),
        subtitle: subtitle,
        icon: HugeIcons.strokeRoundedUserAdd01,
        tone: ClassTone.of(context, SacAccent.of(context).color),
        onTap: () => context.push(RouteNames.familyAdd),
        enabled: enabled,
      );

  /// Redeem a second-guardian or director claim code (FP-62).
  factory _FamilyOption.code(BuildContext context) => _FamilyOption(
        title: 'family.option.code_title'.tr(),
        subtitle: 'family.option.code_subtitle'.tr(),
        icon: HugeIcons.strokeRoundedKey01,
        // Secondary way in: neutral, so the accent marks the main one.
        tone: ClassTone(
          container: context.sac.surfaceVariant,
          onContainer: context.sac.textSecondary,
        ),
        onTap: () => context.push(RouteNames.familyLink),
      );

  final String title;
  final String subtitle;
  final HugeIconData icon;
  final ClassTone tone;
  final VoidCallback onTap;
  final bool enabled;
}

class _OptionSurface extends StatelessWidget {
  const _OptionSurface({required this.option, required this.child});

  final _FamilyOption option;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final radius = BorderRadius.circular(AppTheme.radiusMD);
    return Semantics(
      button: true,
      enabled: option.enabled,
      label: '${option.title}. ${option.subtitle}',
      excludeSemantics: true,
      child: Opacity(
        opacity: option.enabled ? 1 : AppTheme.disabledOpacity,
        child: Material(
          color: c.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: SacInkWell(
            onTap: option.enabled ? option.onTap : null,
            borderRadius: radius,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _OptionWell extends StatelessWidget {
  const _OptionWell({required this.option, this.size = 44});

  final _FamilyOption option;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: option.tone.container,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: HugeIcon(
        icon: option.icon,
        size: size / 2,
        color: option.tone.onContainer,
      ),
    );
  }
}

/// Full-width option (empty state).
class _FamilyOptionRow extends StatelessWidget {
  const _FamilyOptionRow({super.key, required this.option});

  final _FamilyOption option;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _OptionSurface(
      option: option,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _OptionWell(option: option),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: SacFontSize.titleMedium,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: TextStyle(
                      fontSize: SacFontSize.bodyMedium,
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 18,
              color: c.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Half-width bento option (below the list of minors).
class _FamilyOptionTile extends StatelessWidget {
  const _FamilyOptionTile({super.key, required this.option});

  final _FamilyOption option;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return _OptionSurface(
      option: option,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OptionWell(option: option, size: 40),
            const SizedBox(height: 10),
            Text(
              option.title,
              style: TextStyle(
                fontSize: SacFontSize.titleSmall,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              option.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: SacFontSize.bodySmall,
                color: c.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.text,
    required this.tone,
  });

  final int number;
  final String text;
  final ClassTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(color: tone.container, shape: BoxShape.circle),
          child: Text(
            '$number',
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w700,
              color: tone.onContainer,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                fontSize: SacFontSize.bodyMedium,
                color: c.textSecondary,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: SacFontSize.labelSmall,
          fontWeight: FontWeight.w600,
          color: context.sac.textTertiary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
