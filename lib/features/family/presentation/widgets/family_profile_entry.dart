import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/class_tone.dart';
import '../../../../core/theme/sac_accent.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../../auth/presentation/providers/acting_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/family_providers.dart';
import 'profile_switcher_sheet.dart';

/// «Mi familia» in the profile, only for guardians with at least one minor.
///
/// Most users have no minors, so without them nothing is drawn here: the
/// entry to register one lives in Ajustes › Cuenta. With minors it is one
/// row: tapping it opens Mi familia, «Cambiar» opens the profile switcher.
///
/// Nothing is drawn while acting for a dependent (FP-57) or for a supervised
/// teen / account without age (FP3-32): the router also blocks /family.
class FamilyProfileEntry extends ConsumerWidget {
  const FamilyProfileEntry({super.key, required this.horizontalPadding});

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(actingDependentProvider) != null) {
      return const SizedBox.shrink();
    }
    final isTeen = ref.watch(
      authNotifierProvider.select((v) => v.value?.isLimitedAccount ?? false),
    );
    if (isTeen) return const SizedBox.shrink();
    final count = ref.watch(
      authNotifierProvider.select((v) => v.value?.family?.dependentsCount ?? 0),
    );
    if (count == 0) return const SizedBox.shrink();

    final c = context.sac;
    // Names and initials when the list is at hand; the count alone otherwise.
    final dependents =
        ref.watch(dependentsProvider).value?.dependents ?? const [];
    final names = [
      for (final d in dependents)
        if ((d.name ?? '').trim().isNotEmpty) d.name!.trim(),
    ];
    final accent = SacAccent.of(context);
    final title = 'family.profile.entry_count'.plural(count, name: 'count');

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, 20, horizontalPadding, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'family.profile.entry_title'.tr().toUpperCase(),
            style: TextStyle(
              fontSize: SacFontSize.labelSmall,
              fontWeight: FontWeight.w600,
              color: c.textTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              side: BorderSide(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: SacInkWell(
              onTap: () => context.push(RouteNames.family),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    _InitialsStack(names: names, count: count),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        button: true,
                        label: [
                          'family.profile.entry_title'.tr(),
                          title,
                          if (names.isNotEmpty) names.join(', '),
                        ].join('. '),
                        excludeSemantics: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: SacFontSize.titleSmall,
                                fontWeight: FontWeight.w600,
                                color: c.text,
                              ),
                            ),
                            if (names.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                names.join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: SacFontSize.bodySmall,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: const ValueKey('family-entry-switch'),
                      onPressed: () => showProfileSwitcherSheet(context),
                      style: TextButton.styleFrom(
                        backgroundColor: accent.light,
                        foregroundColor: accent.dark,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text('family.profile.switch_short'.tr()),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Up to three overlapping initials circles; a single well when the names
/// are not loaded yet.
class _InitialsStack extends StatelessWidget {
  const _InitialsStack({required this.names, required this.count});

  final List<String> names;
  final int count;

  static const _palette = [
    AppColors.colorViajero,
    AppColors.secondary,
    AppColors.accent,
  ];
  static const double _size = 34;
  static const double _overlap = 12;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final shown = names.take(3).toList();
    if (shown.isEmpty) {
      final tone = ClassTone.of(context, AppColors.colorViajero);
      return Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: tone.container, shape: BoxShape.circle),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: SacFontSize.bodyMedium,
            fontWeight: FontWeight.w700,
            color: tone.onContainer,
          ),
        ),
      );
    }

    return SizedBox(
      width: _size + (shown.length - 1) * (_size - _overlap),
      height: _size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * (_size - _overlap),
              child: Builder(builder: (context) {
                final tone = ClassTone.of(context, _palette[i]);
                return Container(
                  width: _size,
                  height: _size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.container,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                  ),
                  child: Text(
                    _initials(shown[i]),
                    style: TextStyle(
                      fontSize: SacFontSize.labelSmall,
                      fontWeight: FontWeight.w700,
                      color: tone.onContainer,
                    ),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}
