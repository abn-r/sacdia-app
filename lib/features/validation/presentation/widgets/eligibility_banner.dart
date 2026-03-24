import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/widgets/sac_loading.dart';
import '../providers/validation_providers.dart';

/// Banner compacto que muestra la elegibilidad para investidura del usuario.
///
/// Uso:
/// ```dart
/// EligibilityBanner(userId: 'user-uuid-here')
/// ```
class EligibilityBanner extends ConsumerWidget {
  final String userId;

  const EligibilityBanner({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibilityAsync = ref.watch(eligibilityProvider(userId));
    final c = context.sac;

    return eligibilityAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SacLoading(),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (eligibility) {
        final percent = eligibility.completionPercent.clamp(0.0, 100.0);
        final isEligible = eligibility.eligible;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isEligible ? AppColors.secondaryLight : c.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isEligible
                  ? AppColors.secondary.withValues(alpha: 0.4)
                  : c.border,
            ),
          ),
          child: Row(
            children: [
              // ── Icon ────────────────────────────────────────────────
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isEligible
                      ? AppColors.secondary.withValues(alpha: 0.2)
                      : c.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: HugeIcon(
                    icon: isEligible
                        ? HugeIcons.strokeRoundedStarCircle
                        : HugeIcons.strokeRoundedClock02,
                    color: isEligible
                        ? AppColors.secondaryDark
                        : c.textSecondary,
                    size: 20,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ── Text + progress ──────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Apto para investidura:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isEligible ? 'Sí' : 'No',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isEligible
                                ? AppColors.secondaryDark
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percent / 100.0,
                        backgroundColor: c.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isEligible
                              ? AppColors.secondary
                              : AppColors.accent,
                        ),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${percent.toStringAsFixed(0)}% completado',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
