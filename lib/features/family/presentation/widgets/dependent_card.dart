import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_button.dart';
import '../../../../core/widgets/sac_card.dart';
import '../../domain/entities/dependent.dart';
import 'consent_badge.dart';
import 'dependent_avatar.dart';

/// Línea de estado del club de un menor ("Sin club", "Solicitud pendiente en…").
String dependentClubLabel(DependentClubMembership? membership) {
  if (membership == null) return 'family.club.none'.tr();
  final club = membership.clubName ?? '';
  return switch (membership.status) {
    'active' => 'family.club.active'.tr(namedArgs: {'club': club}),
    'pending' => 'family.club.pending'.tr(namedArgs: {'club': club}),
    'rejected' => 'family.club.rejected'.tr(),
    'expired' => 'family.club.expired'.tr(),
    'cancelled' => 'family.club.cancelled'.tr(),
    _ => 'family.club.none'.tr(),
  };
}

/// Tarjeta de un menor en Mi familia.
class DependentCard extends StatelessWidget {
  const DependentCard({
    super.key,
    required this.dependent,
    required this.onOpen,
    required this.onViewAs,
  });

  final DependentSummary dependent;
  final VoidCallback onOpen;

  /// Cambia al perfil del menor. Nulo/oculto si está congelado.
  final VoidCallback onViewAs;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final textTheme = Theme.of(context).textTheme;
    final age = dependent.age;

    return SacCard(
      onTap: onOpen,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DependentAvatar(
                name: dependent.firstName,
                imageUrl: dependent.userImage,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dependent.fullName,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (age != null)
                      Text(
                        'family.card.age'.tr(namedArgs: {'age': '$age'}),
                        style: textTheme.bodySmall?.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 20,
                color: c.textTertiary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (dependent.frozen)
                SacBadge.error(
                  label: 'family.frozen'.tr(),
                  icon: HugeIcons.strokeRoundedSnow,
                )
              else
                ConsentBadge(status: dependent.guardianship.consentStatus),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            dependent.frozen
                ? 'family.frozen_hint'.tr()
                : dependentClubLabel(dependent.clubMembership),
            style: textTheme.bodySmall?.copyWith(color: c.textSecondary),
          ),
          // Con acceso propio activo ya no se actúa por él (lo niega el servidor).
          if (dependent.canActAs) ...[
            const SizedBox(height: 12),
            SacButton.outline(
              text: 'family.card.view_as'.tr(
                namedArgs: {'name': dependent.firstName},
              ),
              icon: HugeIcons.strokeRoundedUserSwitch,
              onPressed: onViewAs,
            ),
          ],
        ],
      ),
    );
  }
}
