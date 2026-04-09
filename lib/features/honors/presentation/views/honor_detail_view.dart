import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/honor.dart';
import '../../domain/entities/user_honor_requirement_progress.dart';
import '../../domain/utils/honor_category_colors.dart';
import '../providers/honors_providers.dart';
import '../../domain/entities/user_honor.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────

// Note: background, surface, text, and border colors are resolved at runtime
// via context.sac.* to support light and dark themes. See SacColors extension.
const _kScreenPad = 20.0;
const _kSectionGap = 24.0;
const _kHeroHeight = 300.0;

// ── Label helpers ─────────────────────────────────────────────────────────────

String _approvalLabel(int level) {
  switch (level) {
    case 1:
      return 'General';
    case 2:
      return 'Avanzado';
    case 3:
      return 'Master';
    default:
      return 'Nivel $level';
  }
}

String _skillLevelLabel(int? level) {
  switch (level) {
    case 1:
      return 'Básico';
    case 2:
      return 'Intermedio';
    case 3:
      return 'Avanzado';
    default:
      return level != null ? 'Nivel $level' : '';
  }
}

// ── Main View ─────────────────────────────────────────────────────────────────

class HonorDetailView extends ConsumerWidget {
  final int honorId;
  final Honor? initialHonor;

  const HonorDetailView({
    super.key,
    required this.honorId,
    this.initialHonor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialHonor != null) {
      return _HonorDetailContent(honor: initialHonor!, honorId: honorId);
    }

    final honorAsync = ref.watch(allHonorsProvider);
    return honorAsync.when(
      data: (honors) {
        try {
          final honor = honors.firstWhere((h) => h.id == honorId);
          return _HonorDetailContent(honor: honor, honorId: honorId);
        } catch (_) {
          return _ErrorScaffold(onRetry: () => ref.invalidate(allHonorsProvider));
        }
      },
      loading: () => const _LoadingScaffold(),
      error: (_, __) =>
          _ErrorScaffold(onRetry: () => ref.invalidate(allHonorsProvider)),
    );
  }
}

// ── Loading Scaffold ───────────────────────────────────────────────────────────

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      body: Column(
        children: [
          Container(
            height: _kHeroHeight,
            color: AppColors.sacBlack.withValues(alpha: 0.85),
            child: const SafeArea(
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          Expanded(child: Container(color: context.sac.background)),
        ],
      ),
    );
  }
}

// ── Error Scaffold ─────────────────────────────────────────────────────────────

class _ErrorScaffold extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorScaffold({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: AppBar(
        backgroundColor: AppColors.sacBlack,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'No se pudo cargar la especialidad',
              style: TextStyle(fontSize: 15, color: context.sac.textSecondary),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: onRetry,
              child: const Text(
                'Reintentar',
                style: TextStyle(color: AppColors.sacBlue, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Detail Content ─────────────────────────────────────────────────────────────

class _HonorDetailContent extends ConsumerWidget {
  final Honor honor;
  final int honorId;

  const _HonorDetailContent({required this.honor, required this.honorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userHonor = ref.watch(userHonorForHonorProvider(honorId));
    final userHonorsLoading = ref.watch(userHonorsProvider).isLoading;
    final enrollAsync = ref.watch(honorEnrollmentNotifierProvider);
    final categoriesAsync = ref.watch(honorCategoriesProvider);

    final categoryName = categoriesAsync.maybeWhen(
      data: (cats) {
        try {
          return cats.firstWhere((c) => c.id == honor.categoryId).name;
        } catch (_) {
          return null;
        }
      },
      orElse: () => null,
    );

    final categoryColor = getCategoryColor(categoryId: honor.categoryId);
    final isEnrolled = userHonor != null;

    // After enrollment, refresh providers so UI switches to enrolled state
    if (!userHonorsLoading && enrollAsync.hasValue && enrollAsync.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.invalidate(userHonorsProvider);
          ref.invalidate(userHonorForHonorProvider(honorId));
          ref.invalidate(honorEnrollmentNotifierProvider);
        }
      });
    }

    return Scaffold(
      backgroundColor: context.sac.background,
      body: Stack(
        children: [
          // ── Scrollable content ──────────────────────────────────────
          CustomScrollView(
            slivers: [
              // Hero SliverAppBar
              SliverAppBar(
                expandedHeight: _kHeroHeight,
                pinned: true,
                backgroundColor: categoryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                leading: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                title: Text(
                  categoryName ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                actions: isEnrolled
                    ? [
                        _StatusBadgePill(status: userHonor.displayStatus),
                        const SizedBox(width: 12),
                      ]
                    : null,
                flexibleSpace: FlexibleSpaceBar(
                  background: _HeroSection(
                    honor: honor,
                    categoryColor: categoryColor,
                    userHonor: userHonor,
                    honorId: honorId,
                    isEnrolled: isEnrolled,
                  ),
                ),
              ),

              // ── Body cards ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _kScreenPad),
                  child: _StaggeredCards(
                    honor: honor,
                    honorId: honorId,
                    categoryColor: categoryColor,
                    userHonor: userHonor,
                    isEnrolled: isEnrolled,
                    userHonorsLoading: userHonorsLoading,
                    enrollAsync: enrollAsync,
                  ),
                ),
              ),
            ],
          ),

          // ── Floating CTA ────────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _BottomCtaBar(
              honor: honor,
              honorId: honorId,
              userHonor: userHonor,
              isEnrolled: isEnrolled,
              categoryColor: categoryColor,
              userHonorsLoading: userHonorsLoading,
              enrollAsync: enrollAsync,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero Section ───────────────────────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  final Honor honor;
  final Color categoryColor;
  final UserHonor? userHonor;
  final int honorId;
  final bool isEnrolled;

  const _HeroSection({
    required this.honor,
    required this.categoryColor,
    required this.userHonor,
    required this.honorId,
    required this.isEnrolled,
  });

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _badgeScale;
  late Animation<double> _progressValue;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _badgeScale = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _progressValue = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    // Delay slightly so the hero renders first
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final progressStats = widget.isEnrolled
            ? ref.watch(honorProgressStatsProvider(widget.honorId))
            : null;
        final progressPercent = progressStats?.percentage ?? 0.0;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.categoryColor,
                widget.categoryColor.withValues(alpha: 0.72),
              ],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Badge with optional progress ring
                  ScaleTransition(
                    scale: _badgeScale,
                    child: widget.isEnrolled
                        ? _ProgressBadge(
                            honor: widget.honor,
                            categoryColor: widget.categoryColor,
                            progressValue: _progressValue,
                            progressPercent: progressPercent,
                          )
                        : _SimpleBadge(honor: widget.honor),
                  ),

                  const SizedBox(height: 16),

                  // Honor name
                  Text(
                    widget.honor.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (widget.isEnrolled && progressStats != null) ...[
                    // Progress summary text
                    Text(
                      '${progressStats.completed} de ${progressStats.total} completados',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Thin progress bar
                    AnimatedBuilder(
                      animation: _progressValue,
                      builder: (context, _) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _progressValue.value * progressPercent,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    // Skill level + approval pills
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        if (widget.honor.skillLevel != null)
                          _FrostedPill(
                              label: _skillLevelLabel(widget.honor.skillLevel)),
                        _FrostedPill(label: _approvalLabel(widget.honor.approval)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SimpleBadge extends StatelessWidget {
  final Honor honor;

  const _SimpleBadge({required this.honor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: _BadgeImage(honor: honor),
      ),
    );
  }
}

class _ProgressBadge extends StatelessWidget {
  final Honor honor;
  final Color categoryColor;
  final Animation<double> progressValue;
  final double progressPercent;

  const _ProgressBadge({
    required this.honor,
    required this.categoryColor,
    required this.progressValue,
    required this.progressPercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      height: 130,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipOval(
        child: _BadgeImage(honor: honor),
      ),
    );
  }
}

class _BadgeImage extends StatelessWidget {
  final Honor honor;

  const _BadgeImage({required this.honor});

  @override
  Widget build(BuildContext context) {
    if (honor.imageUrl != null && honor.imageUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: honor.imageUrl!,
        fit: BoxFit.contain,
        memCacheWidth: 390,
        memCacheHeight: 390,
        errorWidget: (_, __, ___) => HugeIcon(
          icon: HugeIcons.strokeRoundedAward01,
          size: 36,
          color: AppColors.sacBlack,
        ),
      );
    }
    return HugeIcon(
      icon: HugeIcons.strokeRoundedAward01,
      size: 36,
      color: AppColors.sacBlack,
    );
  }
}

class _FrostedPill extends StatelessWidget {
  final String label;

  const _FrostedPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusBadgePill extends StatelessWidget {
  final String status;

  const _StatusBadgePill({required this.status});

  Color _bgColor() {
    switch (status) {
      case 'validado':
        return AppColors.sacGreen;
      case 'enviado':
        return AppColors.sacYellow;
      case 'rechazado':
        return AppColors.sacRed;
      default:
        return Colors.white.withValues(alpha: 0.25);
    }
  }

  String _label() {
    switch (status) {
      case 'validado':
        return 'Validada';
      case 'enviado':
        return 'En revisión';
      case 'en_progreso':
        return 'En progreso';
      case 'rechazado':
        return 'Rechazada';
      default:
        return 'Inscrita';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Staggered Cards Body ───────────────────────────────────────────────────────

class _StaggeredCards extends StatefulWidget {
  final Honor honor;
  final int honorId;
  final Color categoryColor;
  final UserHonor? userHonor;
  final bool isEnrolled;
  final bool userHonorsLoading;
  final AsyncValue<UserHonor?> enrollAsync;

  const _StaggeredCards({
    required this.honor,
    required this.honorId,
    required this.categoryColor,
    required this.userHonor,
    required this.isEnrolled,
    required this.userHonorsLoading,
    required this.enrollAsync,
  });

  @override
  State<_StaggeredCards> createState() => _StaggeredCardsState();
}

class _StaggeredCardsState extends State<_StaggeredCards>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _fadeAnims;
  late List<Animation<Offset>> _slideAnims;

  @override
  void initState() {
    super.initState();
    // 4 cards max
    const count = 4;
    _controllers = List.generate(
      count,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );
    _fadeAnims = _controllers
        .map((c) => Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: c, curve: Curves.easeOut),
            ))
        .toList();
    _slideAnims = _controllers
        .map((c) => Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: c, curve: Curves.easeOut)))
        .toList();

    // Stagger cards with 100ms delay each
    for (var i = 0; i < count; i++) {
      Future.delayed(Duration(milliseconds: 150 + i * 100), () {
        if (mounted) _controllers[i].forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _animated(int index, Widget child) {
    final idx = index.clamp(0, _controllers.length - 1);
    return FadeTransition(
      opacity: _fadeAnims[idx],
      child: SlideTransition(position: _slideAnims[idx], child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEnrolled) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _kSectionGap),

          // Quick stats row
          _animated(
            0,
            _QuickStatsRow(
              honorId: widget.honorId,
              userHonor: widget.userHonor!,
              categoryColor: widget.categoryColor,
            ),
          ),
          const SizedBox(height: _kSectionGap),

          // Requirements preview
          _animated(
            1,
            _RequirementsPreviewCard(
              honorId: widget.honorId,
              userHonorId: widget.userHonor!.id,
              honorName: widget.honor.name,
              categoryColor: widget.categoryColor,
            ),
          ),
          const SizedBox(height: _kSectionGap),

          // Evidence section
          _animated(
            2,
            _EvidenceSection(
              userHonor: widget.userHonor!,
              honorId: widget.honorId,
              categoryColor: widget.categoryColor,
            ),
          ),

          // Material download (if available)
          if (widget.honor.materialUrl != null &&
              widget.honor.materialUrl!.isNotEmpty) ...[
            const SizedBox(height: _kSectionGap),
            _animated(
              3,
              _MaterialDownloadCard(
                materialUrl: widget.honor.materialUrl!,
                categoryColor: widget.categoryColor,
              ),
            ),
            const SizedBox(height: 30),
          ],

          // Bottom padding for CTA
          const SizedBox(height: 100),
        ],
      );
    }

    // NOT ENROLLED state
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _kSectionGap),

        _animated(
          0,
          _JourneyPreviewCard(
            honor: widget.honor,
            honorId: widget.honorId,
            categoryColor: widget.categoryColor,
          ),
        ),

        if (widget.honor.description != null &&
            widget.honor.description!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _animated(
            1,
            _DescriptionSection(description: widget.honor.description),
          ),
        ],

        const SizedBox(height: 16),
        _animated(
          2,
          _JourneyStepperPath(categoryColor: widget.categoryColor),
        ),

        const SizedBox(height: 120),
      ],
    );
  }
}

// ── Journey Preview Card (NOT ENROLLED) ───────────────────────────────────────

class _JourneyPreviewCard extends ConsumerWidget {
  final Honor honor;
  final int honorId;
  final Color categoryColor;

  const _JourneyPreviewCard({
    required this.honor,
    required this.honorId,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requirementsAsync = ref.watch(honorRequirementsProvider(honorId));
    final requirementsCount = requirementsAsync.maybeWhen(
      data: (reqs) => reqs.length,
      orElse: () => null,
    );

    return _ShadowCard(
      child: Column(
        children: [
          _PreviewRow(
            icon: HugeIcons.strokeRoundedTaskEdit01,
            iconColor: categoryColor,
            label: requirementsCount != null
                ? '$requirementsCount requisitos'
                : 'Cargando requisitos...',
          ),
          _CardDivider(),
          _PreviewRow(
            icon: HugeIcons.strokeRoundedStar,
            iconColor: categoryColor,
            label: honor.skillLevel != null
                ? 'Nivel: ${_skillLevelLabel(honor.skillLevel)}'
                : 'Nivel: General',
          ),
          if (honor.materialUrl != null && honor.materialUrl!.isNotEmpty) ...[
            _CardDivider(),
            _PreviewRow(
              icon: HugeIcons.strokeRoundedPdf01,
              iconColor: categoryColor,
              label: 'Material disponible',
              trailing: Icon(
                Icons.download_rounded,
                size: 16,
                color: categoryColor,
              ),
            ),
          ],
          const SizedBox(width: 300),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final HugeIconData icon;
  final Color iconColor;
  final String label;
  final Widget? trailing;

  const _PreviewRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: HugeIcon(icon: icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: context.sac.text,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _CardDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      color: context.sac.border,
    );
  }
}

// ── Description Section ───────────────────────────────────────────────────────

class _DescriptionSection extends StatefulWidget {
  final String? description;

  const _DescriptionSection({required this.description});

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.description == null || widget.description!.isEmpty) {
      return const SizedBox.shrink();
    }

    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Descripción',
              style: TextStyle(
                color: context.sac.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: Text(
                widget.description!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.sac.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              secondChild: Text(
                widget.description!,
                style: TextStyle(
                  color: context.sac.textSecondary,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Ver menos' : 'Ver más',
                style: TextStyle(
                  color: AppColors.sacBlue,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Journey Stepper Path (NOT ENROLLED — ¿Cómo funciona?) ────────────────────

class _JourneyStepperPath extends StatelessWidget {
  final Color categoryColor;

  const _JourneyStepperPath({required this.categoryColor});

  static const _steps = [
    (
      title: 'Regístrate',
      subtitle: 'Regístrate en la especialidad para comenzar tu camino',
    ),
    (
      title: 'Completa los requisitos',
      subtitle: 'Marca cada requisito cumplido en la app o con tu instructor',
    ),
    (
      title: 'Sube las evidencias',
      subtitle: 'Fotografía o escanea las hojas firmadas como respaldo',
    ),
    (
      title: 'Envía a revisión',
      subtitle: 'Cuando estés listo, envía tu progreso para ser validado',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Cómo funciona?',
              style: TextStyle(
                color: context.sac.text,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ..._steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final isLast = i == _steps.length - 1;
              return _StepItem(
                index: i,
                title: step.title,
                subtitle: step.subtitle,
                categoryColor: categoryColor,
                isLast: isLast,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int index;
  final String title;
  final String subtitle;
  final Color categoryColor;
  final bool isLast;

  const _StepItem({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.categoryColor,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Number + dotted connector
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Numbered circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: categoryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                // Dotted line connector
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: CustomPaint(
                        painter: _DottedLinePainter(color: categoryColor.withValues(alpha: 0.35)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Text content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: TextStyle(
                      color: context.sac.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.sac.textSecondary,
                      fontSize: 12,
                      height: 1.5,
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
}

class _DottedLinePainter extends CustomPainter {
  final Color color;

  const _DottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    const dotHeight = 4.0;
    const gapHeight = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, math.min(y + dotHeight, size.height)), paint);
      y += dotHeight + gapHeight;
    }
  }

  @override
  bool shouldRepaint(_DottedLinePainter old) => old.color != color;
}

// ── Quick Stats Row (ENROLLED) ────────────────────────────────────────────────

class _QuickStatsRow extends ConsumerWidget {
  final int honorId;
  final UserHonor userHonor;
  final Color categoryColor;

  const _QuickStatsRow({
    required this.honorId,
    required this.userHonor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(honorProgressStatsProvider(honorId));
    final remaining = (stats.total - stats.completed).clamp(0, stats.total);

    return Row(
      children: [
        Expanded(
          child: _StatMiniCard(
            value: '${stats.completed}',
            label: 'completados',
            categoryColor: categoryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            value: '$remaining',
            label: 'pendientes',
            categoryColor: categoryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatMiniCard(
            value: '${userHonor.evidenceCount}',
            label: 'evidencias',
            categoryColor: categoryColor,
          ),
        ),
      ],
    );
  }
}

class _StatMiniCard extends StatelessWidget {
  final String value;
  final String label;
  final Color categoryColor;

  const _StatMiniCard({
    required this.value,
    required this.label,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: categoryColor.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: categoryColor,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.sac.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Requirements Preview Card (ENROLLED) ─────────────────────────────────────

class _RequirementsPreviewCard extends ConsumerWidget {
  final int honorId;
  final int userHonorId;
  final String honorName;
  final Color categoryColor;

  const _RequirementsPreviewCard({
    required this.honorId,
    required this.userHonorId,
    required this.honorName,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userHonorProgressProvider(honorId));

    return progressAsync.when(
      data: (progressList) {
        // Show first 4 requirements
        final preview = progressList.take(4).toList();
        final remaining = (progressList.length - preview.length).clamp(0, progressList.length);

        return _ShadowCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedTaskEdit01,
                      size: 18,
                      color: categoryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Requisitos',
                        style: TextStyle(
                          color: context.sac.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              _CardDivider(),
              ...preview.map((req) => _RequirementPreviewItem(
                    requirement: req,
                    categoryColor: categoryColor,
                  )),
              if (remaining > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Text(
                    'y $remaining más...',
                    style: TextStyle(
                      color: context.sac.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push(
                      RouteNames.honorRequirementsPath(
                        honorId.toString(),
                        userHonorId.toString(),
                        honorName,
                      ),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: categoryColor, width: 1.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Completar requisitos',
                          style: TextStyle(
                            color: categoryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: categoryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => _ShadowCard(
        child: Container(
          height: 140,
          alignment: Alignment.center,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: categoryColor,
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _RequirementPreviewItem extends StatelessWidget {
  final UserHonorRequirementProgress requirement;
  final Color categoryColor;

  const _RequirementPreviewItem({
    required this.requirement,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool completed = requirement.completed;
    final String text = requirement.text;
    final int number = requirement.requirementNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Check icon
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? AppColors.sacGreen.withValues(alpha: 0.12)
                  : context.sac.surfaceVariant,
              border: Border.all(
                color: completed ? AppColors.sacGreen : context.sac.border,
                width: 1.5,
              ),
            ),
            child: completed
                ? const Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: AppColors.sacGreen,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$number. $text',
              style: TextStyle(
                color: completed ? context.sac.textTertiary : context.sac.text,
                fontSize: 13,
                height: 1.5,
                decoration: completed ? TextDecoration.lineThrough : null,
                decorationColor: context.sac.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Evidence Section (ENROLLED) ───────────────────────────────────────────────

class _EvidenceSection extends StatelessWidget {
  final UserHonor userHonor;
  final int honorId;
  final Color categoryColor;

  const _EvidenceSection({
    required this.userHonor,
    required this.honorId,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(
                  icon: HugeIcons.strokeRoundedImage01,
                  size: 18,
                  color: categoryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  userHonor.evidenceCount > 0
                      ? '${userHonor.evidenceCount} archivos subidos'
                      : 'Sin evidencia aún',
                  style: TextStyle(
                    color: context.sac.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            // Thumbnail row
            if (userHonor.images.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: userHonor.images.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: userHonor.images[index],
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        memCacheWidth: 168,
                        memCacheHeight: 168,
                        errorWidget: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: context.sac.border,
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 20,
                            color: context.sac.textTertiary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 14),

            // Evidence button
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(
                  RouteNames.honorEvidencePath(
                    honorId.toString(),
                    userHonor.id.toString(),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: categoryColor, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Subir evidencia',
                      style: TextStyle(
                        color: categoryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: categoryColor,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Material Download Card ────────────────────────────────────────────────────

class _MaterialDownloadCard extends StatefulWidget {
  final String materialUrl;
  final Color categoryColor;

  const _MaterialDownloadCard({
    required this.materialUrl,
    required this.categoryColor,
  });

  @override
  State<_MaterialDownloadCard> createState() => _MaterialDownloadCardState();
}

class _MaterialDownloadCardState extends State<_MaterialDownloadCard> {
  bool _isLaunching = false;

  Future<void> _openMaterial() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    try {
      final uri = Uri.tryParse(widget.materialUrl);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        _showError('No se pudo abrir el material');
        return;
      }
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('No se pudo abrir el material');
      }
    } catch (_) {
      _showError('Error al abrir el material PDF');
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ShadowCard(
      child: GestureDetector(
        onTap: _openMaterial,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.categoryColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPdf01,
                  size: 20,
                  color: widget.categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Material de estudio',
                      style: TextStyle(
                        color: context.sac.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'PDF — descarga para completar offline',
                      style: TextStyle(
                        color: context.sac.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLaunching)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: widget.categoryColor,
                  ),
                )
              else
                Icon(
                  Icons.download_rounded,
                  color: widget.categoryColor,
                  size: 20,
                ),              
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom CTA Bar ────────────────────────────────────────────────────────────

class _BottomCtaBar extends ConsumerWidget {
  final Honor honor;
  final int honorId;
  final UserHonor? userHonor;
  final bool isEnrolled;
  final Color categoryColor;
  final bool userHonorsLoading;
  final AsyncValue<UserHonor?> enrollAsync;

  const _BottomCtaBar({
    required this.honor,
    required this.honorId,
    required this.userHonor,
    required this.isEnrolled,
    required this.categoryColor,
    required this.userHonorsLoading,
    required this.enrollAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.sac.surface,
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: isEnrolled
              ? _EnrolledCtaButton(
                  userHonor: userHonor!,
                  honor: honor,
                  categoryColor: categoryColor,
                )
              : userHonorsLoading
                  ? _LoadingCtaButton(categoryColor: categoryColor)
                  : enrollAsync.when(
                      data: (enrolled) {
                        if (enrolled != null) return const SizedBox.shrink();
                        return _EnrollCtaButton(
                          honorId: honorId,
                          categoryColor: categoryColor,
                        );
                      },
                      loading: () =>
                          _LoadingCtaButton(categoryColor: categoryColor),
                      error: (err, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              err.toString().replaceAll('Exception: ', ''),
                              style: const TextStyle(
                                color: AppColors.errorDark,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          _EnrollCtaButton(
                            honorId: honorId,
                            categoryColor: categoryColor,
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }
}

// ── Enroll CTA Button ─────────────────────────────────────────────────────────

class _EnrollCtaButton extends ConsumerStatefulWidget {
  final int honorId;
  final Color categoryColor;

  const _EnrollCtaButton({
    required this.honorId,
    required this.categoryColor,
  });

  @override
  ConsumerState<_EnrollCtaButton> createState() => _EnrollCtaButtonState();
}

class _EnrollCtaButtonState extends ConsumerState<_EnrollCtaButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _pressScale = _pressController;
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _onTap() async {
    await _pressController.reverse();
    await _pressController.forward();
    HapticFeedback.mediumImpact();

    final authState = ref.read(authNotifierProvider);
    final userId = authState.value?.id;
    if (userId == null) return;

    await ref
        .read(honorEnrollmentNotifierProvider.notifier)
        .enrollInHonor(userId, widget.honorId);
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pressScale,
      child: GestureDetector(
        onTap: _onTap,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: widget.categoryColor,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: widget.categoryColor.withValues(alpha: 0.30),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Text(
            'Inscribirme',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Loading CTA Button ────────────────────────────────────────────────────────

class _LoadingCtaButton extends StatelessWidget {
  final Color categoryColor;

  const _LoadingCtaButton({required this.categoryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 48,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}

// ── Enrolled CTA Button ───────────────────────────────────────────────────────

class _EnrolledCtaButton extends StatelessWidget {
  final UserHonor userHonor;
  final Honor honor;
  final Color categoryColor;

  const _EnrolledCtaButton({
    required this.userHonor,
    required this.honor,
    required this.categoryColor,
  });

  @override
  Widget build(BuildContext context) {
    // Under review — disabled
    if (userHonor.isUnderReview) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.sacYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sacYellow, width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded, size: 16, color: AppColors.sacYellow),
            SizedBox(width: 8),
            Text(
              'En revisión',
              style: TextStyle(
                color: AppColors.sacYellow,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // Approved — completed state
    if (userHonor.isCompleted) {
      return Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.sacGreen.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sacGreen, width: 1.5),
        ),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, size: 18, color: AppColors.sacGreen),
            SizedBox(width: 8),
            Text(
              'Especialidad completada',
              style: TextStyle(
                color: AppColors.sacGreen,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }

    // Can submit — show submit button (with evidence) or go to evidence (without)
    final bool hasEvidence = userHonor.hasEvidence;
    final label = hasEvidence ? 'Enviar a revisión' : 'Ver mi progreso';

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push(
          RouteNames.honorEvidencePath(
            honor.id.toString(),
            userHonor.id.toString(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: hasEvidence ? categoryColor : categoryColor.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          boxShadow: hasEvidence
              ? [
                  BoxShadow(
                    color: categoryColor.withValues(alpha: 0.30),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ── Shadow Card ───────────────────────────────────────────────────────────────

class _ShadowCard extends StatelessWidget {
  final Widget child;

  const _ShadowCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.sac.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.sac.shadow,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
