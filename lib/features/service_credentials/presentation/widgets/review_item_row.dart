import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/sac_colors.dart';
import '../../../../core/theme/sac_font_size.dart';
import '../../../../core/widgets/sac_member_avatar.dart';
import '../../../../core/widgets/sac_pressable.dart';
import '../../domain/entities/service_credential.dart';
import '../../domain/entities/service_credential_review.dart';
import '../utils/service_credential_labels.dart';
import 'service_credential_status_pill.dart';

/// One row of the review queue: avatar, person, club and credential, the date
/// that matters for its state, and the status pill. The whole row opens the
/// detail (44pt+ target).
class ReviewItemRow extends StatelessWidget {
  const ReviewItemRow({super.key, required this.item, required this.onTap});

  final ReviewItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final name = item.person.name.trim().isEmpty
        ? 'service_credentials.review.unknown_person'.tr()
        : item.person.name.trim();
    final what = serviceCredentialTitle();
    final line2 = [
      if (item.clubName != null) item.clubName!,
      what,
    ].join(' · ');
    final decided = item.status == ServiceCredentialStatus.approved ||
        item.status == ServiceCredentialStatus.rejected;
    final date = decided ? item.reviewedAt : item.createdAt;
    final line3 = date == null
        ? null
        : tr(
            decided
                ? 'service_credentials.review.reviewed_on'
                : 'service_credentials.review.sent_on',
            namedArgs: {'date': serviceCredentialDate(context, date)},
          );

    return SacPressable(
      onTap: onTap,
      semanticLabel: [name, line2, if (line3 != null) line3].join('. '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SacMemberAvatar(
                imageUrl: item.person.photoUrl,
                name: name,
                semanticLabel: name,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.titleSmall,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: SacFontSize.bodySmall,
                        color: c.textSecondary,
                        height: 1.2,
                      ),
                    ),
                    if (line3 != null)
                      Text(
                        line3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: SacFontSize.bodySmall,
                          color: c.textTertiary,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (decided)
                ServiceCredentialStatusPill(status: item.status)
              else
                ExcludeSemantics(
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedArrowRight01,
                    size: 18,
                    color: c.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
