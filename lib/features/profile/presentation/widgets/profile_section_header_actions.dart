import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/page_transitions.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';
import 'package:sacdia_app/features/classes/presentation/views/classes_list_view.dart';
import 'package:sacdia_app/features/honors/presentation/providers/honors_providers.dart';
import 'profile_quiet_add_chip.dart';

/// Clases header actions. The empty state of `ProfileClassesSection` already
/// carries an "Agregar" chip, so the header one is hidden then to keep a
/// single call to action.
class ProfileClassesHeaderActions extends ConsumerWidget {
  final VoidCallback onRefresh;

  const ProfileClassesHeaderActions({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmpty = ref.watch(
      userClassesProvider.select(
          (classes) => classes.hasValue && classes.requireValue.isEmpty),
    );
    return ProfileSectionHeaderActions(
      addSemanticLabel: 'profile.classes_section.browse_classes'.tr(),
      onAdd: () {
        Navigator.push(
          context,
          SacSharedAxisRoute(builder: (_) => const ClassesListView()),
        );
      },
      onRefresh: onRefresh,
      showAdd: !isEmpty,
    );
  }
}

/// Certificaciones header actions. Same rule as [ProfileClassesHeaderActions]:
/// the empty state of `ProfileCertificationsSection` owns the "Agregar" chip.
class ProfileCertificationsHeaderActions extends ConsumerWidget {
  final VoidCallback onRefresh;

  const ProfileCertificationsHeaderActions({
    super.key,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmpty = ref.watch(
      userCertificationsProvider.select(
        (certifications) =>
            certifications.hasValue && certifications.requireValue.isEmpty,
      ),
    );
    return ProfileSectionHeaderActions(
      addSemanticLabel:
          'profile.certifications_section.browse_certifications'.tr(),
      onAdd: () => context.push(RouteNames.homeCertifications),
      onRefresh: onRefresh,
      showAdd: !isEmpty,
    );
  }
}

/// Especialidades header actions. The empty state of `ProfileHonorsSection`
/// already carries an "Agregar" chip, so the header one is hidden then to keep
/// a single call to action.
class ProfileHonorsHeaderActions extends ConsumerWidget {
  final VoidCallback onRefresh;

  const ProfileHonorsHeaderActions({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isEmpty = ref.watch(
      sectionScopedUserHonorsProvider
          .select((honors) => honors.hasValue && honors.requireValue.isEmpty),
    );
    return ProfileSectionHeaderActions(
      addSemanticLabel: 'profile.honors_section.add_honor'.tr(),
      onAdd: () => context.push(RouteNames.homeHonors),
      onRefresh: onRefresh,
      showAdd: !isEmpty,
    );
  }
}

/// Quiet "+ Agregar" plus the existing refresh icon, shared by Clases,
/// Certificaciones and Especialidades headers.
class ProfileSectionHeaderActions extends StatelessWidget {
  final String addSemanticLabel;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  /// `false` when the section's empty state already offers the add action.
  final bool showAdd;

  const ProfileSectionHeaderActions({
    super.key,
    required this.addSemanticLabel,
    required this.onAdd,
    required this.onRefresh,
    this.showAdd = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    return Row(
      children: [
        if (showAdd) ...[
          ProfileQuietAddChip(
            semanticLabel: addSemanticLabel,
            onTap: onAdd,
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 32,
          height: 32,
          child: Material(
            color: c.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: c.border),
            ),
            child: SacInkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onRefresh,
              child: Semantics(
                label: 'common.retry'.tr(),
                button: true,
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedRefresh,
                    color: c.textTertiary,
                    size: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
