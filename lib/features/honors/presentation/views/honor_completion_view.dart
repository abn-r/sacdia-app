import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/widgets/sac_loading.dart';

import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor.dart';
import '../../domain/usecases/get_honors.dart';
import '../providers/honors_providers.dart';

// ── Label helpers ─────────────────────────────────────────────────────────────

String _skillLevelLabel(int level) {
  switch (level) {
    case 1:
      return 'Básico';
    case 2:
      return 'Intermedio';
    case 3:
      return 'Avanzado';
    default:
      return 'Nivel $level';
  }
}

// ── Main View ─────────────────────────────────────────────────────────────────

/// Celebration screen shown when an honor is completed (validated).
///
/// Green header with checkmark circle, large yellow badge, stats row.
/// Receives [honorId] and [userHonorId] as constructor params.
/// Watches [userHonorForHonorProvider] to resolve [UserHonor] data.
class HonorCompletionView extends ConsumerWidget {
  final int honorId;
  final int userHonorId;

  const HonorCompletionView({
    super.key,
    required this.honorId,
    required this.userHonorId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userHonorAsync = ref.watch(userHonorForHonorProvider(honorId));
    final honorsAsync = ref.watch(honorsProvider(const GetHonorsParams()));

    return userHonorAsync.when(
      data: (userHonor) {
        if (userHonor == null) {
          return const _ErrorScaffold(
            message: 'Especialidad no encontrada',
          );
        }

        final honor = honorsAsync.maybeWhen(
          data: (honors) {
            try {
              return honors.firstWhere((h) => h.id == honorId);
            } catch (_) {
              return null;
            }
          },
          orElse: () => null,
        );

        return _CompletionBody(userHonor: userHonor, honor: honor);
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: SacLoading()),
      ),
      error: (_, __) => const _ErrorScaffold(
        message: 'Error al cargar la especialidad',
      ),
    );
  }
}

// ── Error Scaffold ─────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final String message;

  const _ErrorScaffold({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.sacGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.sacGreen,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text(
                'Volver',
                style: TextStyle(color: AppColors.sacBlue, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Completion Body ───────────────────────────────────────────────────────────

class _CompletionBody extends StatelessWidget {
  final UserHonor userHonor;
  final Honor? honor;

  const _CompletionBody({required this.userHonor, this.honor});

  @override
  Widget build(BuildContext context) {
    final honorName = honor?.name ?? userHonor.honorName ?? 'Especialidad';
    final completionDate = userHonor.validatedAt ?? userHonor.date;
    final enrollmentDate = userHonor.date;
    final duration = _durationLabel(enrollmentDate, completionDate);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── Green header SliverAppBar ──────────────────────────
          SliverAppBar(
            expandedHeight: 210,
            pinned: true,
            backgroundColor: AppColors.sacGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.sacGreen,
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 72px white circle with checkmark
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(51),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Title
                      const Text(
                        'Especialidad Completa',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Completion date subtitle
                      Text(
                        '${honorName} \u2022 ${DateFormat('d MMM yyyy', 'es').format(completionDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withAlpha(179),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
              child: Column(
                children: [
                  // Large badge circle (88px, sacYellow)
                  _HonorBadge(honor: honor, userHonor: userHonor),
                  const SizedBox(height: 16),

                  // Honor name
                  Text(
                    honorName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.sacBlack,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Pills: skill level + badge obtained
                  _PillsRow(honor: honor, userHonor: userHonor),
                  const SizedBox(height: 24),

                  // Stats card
                  _StatsCard(
                    userHonor: userHonor,
                    enrollmentDate: enrollmentDate,
                    duration: duration,
                  ),
                  const SizedBox(height: 32),

                  // Primary CTA — "Ver más especialidades"
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        // Pop to catalog — go back until we leave the honor flow
                        context.pop();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sacBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Ver más especialidades',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Secondary — "Volver"
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(
                          color: Color(0xFFE1E6E7),
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Volver',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a human-readable duration string: e.g. "33d" or "2m".
  String _durationLabel(DateTime start, DateTime end) {
    final diff = end.difference(start);
    if (diff.inDays < 0) return '0d';
    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).round();
      return '${months}m';
    }
    return '${diff.inDays}d';
  }
}

// ── Honor Badge ───────────────────────────────────────────────────────────────

/// 88px yellow circle with the honor image or a trophy fallback.
class _HonorBadge extends StatelessWidget {
  final Honor? honor;
  final UserHonor userHonor;

  const _HonorBadge({required this.honor, required this.userHonor});

  String? get _imageUrl =>
      honor?.imageUrl?.isNotEmpty == true
          ? honor!.imageUrl
          : (userHonor.honorImageUrl?.isNotEmpty == true
              ? userHonor.honorImageUrl
              : null);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        color: AppColors.sacYellow,
        shape: BoxShape.circle,
      ),
      child: _imageUrl != null
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: _imageUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            )
          : const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 42,
            ),
    );
  }
}

// ── Pills Row ─────────────────────────────────────────────────────────────────

class _PillsRow extends StatelessWidget {
  final Honor? honor;
  final UserHonor userHonor;

  const _PillsRow({required this.honor, required this.userHonor});

  int? get _skillLevel =>
      honor?.skillLevel ?? userHonor.honorSkillLevel;

  @override
  Widget build(BuildContext context) {
    final skillLevel = _skillLevel;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: [
        // Skill level pill (green tint) — only if data available
        if (skillLevel != null)
          _StatusPill(
            label: _skillLevelLabel(skillLevel),
            color: AppColors.sacGreen,
          ),

        // Badge obtained pill (yellow tint) — always shown on completion
        const _StatusPill(
          label: 'Insignia obtenida',
          color: AppColors.sacYellow,
        ),
      ],
    );
  }
}

// ── Status Pill ───────────────────────────────────────────────────────────────

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Stats Card ────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final UserHonor userHonor;
  final DateTime enrollmentDate;
  final String duration;

  const _StatsCard({
    required this.userHonor,
    required this.enrollmentDate,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Evidence count — sacBlue
            _StatItem(
              value: '${userHonor.evidenceCount}',
              label: 'Evidencias',
              color: AppColors.sacBlue,
            ),

            // Divider
            const VerticalDivider(
              color: Color(0xFFE1E6E7),
              thickness: 1,
              width: 1,
            ),

            // Enrollment date — sacRed
            _StatItem(
              value: DateFormat('d MMM', 'es').format(enrollmentDate),
              label: 'Inscripción',
              color: AppColors.sacRed,
            ),

            // Divider
            const VerticalDivider(
              color: Color(0xFFE1E6E7),
              thickness: 1,
              width: 1,
            ),

            // Duration — sacGreen
            _StatItem(
              value: duration,
              label: 'Duración',
              color: AppColors.sacGreen,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat Item ─────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
