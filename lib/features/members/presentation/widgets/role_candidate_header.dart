import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_member_avatar.dart';

import '../../domain/entities/role_candidate.dart';
import '../utils/role_candidate_labels.dart';
import 'role_candidate_row.dart';

/// Person summary shared by steps 2, 3 and the detail: avatar, name and the
/// Guía Mayor tags. Never shows email or phone.
class RoleCandidateHeader extends StatelessWidget {
  const RoleCandidateHeader({super.key, required this.candidate});

  final RoleCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final hasTags = guideMajorTags(candidate.guideMajor).isNotEmpty;
    return Row(
      children: [
        SacMemberAvatar(
          imageUrl: candidate.photoUrl,
          name: candidate.name,
          size: 48,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                candidate.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: SacFontSize.titleMedium,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                  height: 1.2,
                ),
              ),
              if (hasTags) ...[
                const SizedBox(height: 6),
                RoleCandidateTags(guideMajor: candidate.guideMajor),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
