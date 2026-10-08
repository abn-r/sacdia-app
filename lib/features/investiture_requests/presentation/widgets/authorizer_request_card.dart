import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_badge.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/investiture_request.dart';
import '../utils/investiture_dates.dart';

const _i18n = 'investiture_requests.authorizer';

/// Tarjeta de una solicitud en el listado del autorizador: club, sección,
/// distrito, personas en espera y la fecha más próxima.
class AuthorizerRequestCard extends StatelessWidget {
  const AuthorizerRequestCard({
    super.key,
    required this.request,
    required this.onTap,
  });

  final InvestitureRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final dark = Theme.brightnessOf(context) == Brightness.dark;
    final pending = request.pendingCount ?? request.pendingPeople.length;
    final earliest = request.earliestInvestitureDate;
    final club = request.clubName?.trim();
    final place = [
      if (request.sectionName != null && request.sectionName!.isNotEmpty)
        request.sectionName!,
      if (request.districtName != null && request.districtName!.isNotEmpty)
        tr('$_i18n.district', namedArgs: {'name': request.districtName!}),
    ].join(' · ');

    return Material(
      color: c.paper,
      borderRadius: BorderRadius.circular(18),
      child: SacInkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.ink150),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      AppColors.sentColor.withValues(alpha: dark ? 0.2 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedMedal01,
                    size: 22,
                    color: dark ? AppColors.sentColor : AppColors.sentDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      club == null || club.isEmpty
                          ? tr('$_i18n.club_fallback')
                          : club,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.ink900,
                          ),
                    ),
                    if (place.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        place,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: c.ink500,
                            ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (pending > 0)
                          SacBadge.warning(
                            label: tr(
                              '$_i18n.pending_count',
                              namedArgs: {'count': '$pending'},
                            ),
                            icon: HugeIcons.strokeRoundedClock01,
                          )
                        else
                          Text(
                            tr('$_i18n.nothing_pending'),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.ink500,
                                    ),
                          ),
                        if (earliest != null && pending > 0)
                          Text(
                            tr(
                              '$_i18n.earliest_date',
                              namedArgs: {
                                'date':
                                    formatInvestitureDate(context, earliest),
                              },
                            ),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: c.ink600,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              HugeIcon(
                icon: HugeIcons.strokeRoundedArrowRight01,
                size: 20,
                color: c.ink400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
