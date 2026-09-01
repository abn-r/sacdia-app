import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/animations/motion_tokens.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/features/certifications/domain/entities/user_certification.dart';
import 'package:sacdia_app/features/certifications/presentation/providers/certifications_providers.dart';
import 'profile_quiet_add_chip.dart';

/// Section of the profile view that shows the user's certification
/// enrollments in a 3-column grid, visually consistent with
/// [ProfileClassesSection].
class ProfileCertificationsSection extends ConsumerWidget {
  const ProfileCertificationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certificationsAsync = ref.watch(userCertificationsProvider);

    return AnimatedSwitcher(
      duration: SacMotion.standard,
      child: certificationsAsync.when(
        loading: () => _CertificationsSkeleton(
          key: const ValueKey('certifications-skeleton'),
        ),
        error: (e, _) => Padding(
          key: const ValueKey('certifications-error'),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Center(
            child: Text(
              'profile.certifications_section.error_load'.tr(),
              style: TextStyle(color: AppColors.error, fontSize: 14),
            ),
          ),
        ),
        data: (certifications) {
          if (certifications.isEmpty) {
            return Padding(
              key: const ValueKey('certifications-data'),
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              child: Column(
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedCertificate01,
                    size: 48,
                    color: context.sac.textTertiary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'profile.certifications_section.no_certifications'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      color: context.sac.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ProfileQuietAddChip(
                    semanticLabel:
                        'profile.certifications_section.browse_certifications'
                            .tr(),
                    onTap: () {
                      context.push(RouteNames.homeCertifications);
                    },
                  ),
                ],
              ),
            );
          }

          return Column(
            key: const ValueKey('certifications-data'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GridView.builder(
                // shrinkWrap OK: certification enrollments per user are
                // naturally bounded (small catalog). Lives inside a Column that
                // is itself inside the profile's outer scroll view — intrinsic
                // height is required.
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: certifications.length,
                itemBuilder: (context, index) {
                  return _CertificationGridItem(
                    userCertification: certifications[index],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CertificationGridItem extends StatelessWidget {
  final UserCertification userCertification;

  const _CertificationGridItem({required this.userCertification});

  @override
  Widget build(BuildContext context) {
    final uc = userCertification;
    final isComplete = uc.completionStatus.toLowerCase() == 'completed';
    final color = isComplete ? AppColors.secondary : AppColors.primary;
    final progress = uc.progressPercentage.round();

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              context.push(
                RouteNames.certificationProgressPath(
                  '${uc.certificationId}',
                  '${uc.enrollmentId}',
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: color.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isComplete ? color : color.withAlpha(50),
                      width: isComplete ? 2 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedCertificate01,
                      size: 30,
                      color: color,
                    ),
                  ),
                ),
                if (progress > 0 && !isComplete)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$progress%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (isComplete)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedTick02,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          uc.certificationName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.sac.text,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _CertificationsSkeleton extends StatelessWidget {
  const _CertificationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final skeletonColor = context.sac.surfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      left: i == 0 ? 0 : 5, right: i == 2 ? 0 : 5),
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      color: skeletonColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
