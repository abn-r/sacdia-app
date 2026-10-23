import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../../../../core/widgets/sac_sheet.dart';
import '../../../../core/widgets/sac_snack_bar.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/dependent.dart';
import '../providers/family_providers.dart';
import 'consent_badge.dart';
import 'dependent_avatar.dart';

/// Cambia al perfil de [dependent] y avisa si no se pudo.
///
/// `ACTING_FOR_FORBIDDEN` ya lo avisa el listener global; aquí solo se
/// explican la falta de red y los demás fallos.
Future<SwitchProfileOutcome> switchToDependent(
  BuildContext context,
  WidgetRef ref,
  DependentSummary dependent,
) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final outcome = await ref
      .read(authNotifierProvider.notifier)
      .switchProfile(dependent.userId, firstName: dependent.firstName);

  final message = switch (outcome) {
    SwitchProfileOutcome.offline => 'family.switch.offline'.tr(),
    SwitchProfileOutcome.failed => 'family.switch.failed'.tr(),
    _ => null,
  };
  if (message != null && messenger != null) {
    SacSnackBar.showMessenger(messenger, message, isError: true);
  }
  return outcome;
}

/// Hoja "Cambiar de perfil": Tú + cada menor no congelado (FP-63).
Future<void> showProfileSwitcherSheet(BuildContext context) {
  return showSacSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: context.sac.surface,
    builder: (_) => const ProfileSwitcherSheet(),
  );
}

class ProfileSwitcherSheet extends ConsumerWidget {
  const ProfileSwitcherSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.sac;
    final acting = ref.watch(actingDependentProvider);
    // Durante "actuar por" el estado de auth es el menor: el tutor es la foto.
    final me = ref.watch(guardianUserProvider) ??
        ref.watch(authNotifierProvider).valueOrNull;
    final overview = ref.watch(dependentsProvider);

    Future<void> select(DependentSummary dependent) async {
      Navigator.of(context).pop();
      await switchToDependent(context, ref, dependent);
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SacSheetHeader(
            title: 'family.switcher.title'.tr(),
            showClose: true,
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                _ProfileTile(
                  key: const ValueKey('switcher-you'),
                  avatar: DependentAvatar(
                    name: me?.name ?? '',
                    imageUrl: me?.avatar,
                    size: 44,
                  ),
                  title: 'family.switcher.you'.tr(),
                  subtitle: me?.name,
                  selected: acting == null,
                  onTap: acting == null
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          ref
                              .read(authNotifierProvider.notifier)
                              .switchProfile(null);
                        },
                ),
                const SizedBox(height: 8),
                overview.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: SacLoadingSmall()),
                  ),
                  error: (_, __) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        Text(
                          'family.switcher.load_error'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SacButton.outline(
                          text: 'common.retry'.tr(),
                          onPressed: () => ref.invalidate(dependentsProvider),
                        ),
                      ],
                    ),
                  ),
                  data: (family) {
                    final actable = family.actable;
                    if (actable.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'family.switcher.empty'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: c.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final dependent in actable) ...[
                          _ProfileTile(
                            key: ValueKey('switcher-${dependent.userId}'),
                            avatar: DependentAvatar(
                              name: dependent.firstName,
                              imageUrl: dependent.userImage,
                              size: 44,
                            ),
                            title: dependent.firstName,
                            subtitle: dependent.age == null
                                ? null
                                : 'family.card.age'.tr(
                                    namedArgs: {'age': '${dependent.age}'},
                                  ),
                            trailing: ConsentBadge(
                              status: dependent.guardianship.consentStatus,
                            ),
                            selected: acting?.userId == dependent.userId,
                            onTap: acting?.userId == dependent.userId
                                ? null
                                : () => select(dependent),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    super.key,
    required this.avatar,
    required this.title,
    required this.selected,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget avatar;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final accent = SacAccent.of(context);

    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? accent.light : c.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: c.text,
                                  ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: c.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                  if (selected) ...[
                    const SizedBox(width: 8),
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTick02,
                      size: 20,
                      color: accent.color,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
