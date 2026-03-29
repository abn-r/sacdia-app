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

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/honor.dart';
import '../providers/honors_providers.dart';
import '../../domain/entities/user_honor.dart';

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

/// Vista de detalle de honor — disponible (no inscripto)
///
/// Muestra: header oscuro con ícono y nombre, descripción,
/// tarjeta de material PDF, sección "¿Cómo funciona?" y CTA "Inscribirme".
///
/// Si el usuario ya está inscripto, se redirige (por ahora a esta misma vista
/// con TODO para navegar a la evidence view cuando esté disponible).
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

    // Fallback: look up the honor from the already-cached allHonorsProvider.
    // This avoids issuing GET /honors when navigating from outside the catalog
    // (e.g. deep link, push notification) — the full list may not be in memory yet
    // in those cases, so we fall through to allHonorsProvider which fetches once
    // and is keepAlive.
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
      backgroundColor: AppColors.sacBlack,
      body: Column(
        children: [
          // Skeleton header
          Container(
            color: AppColors.sacBlack,
            height: 180,
            child: const SafeArea(
              child: Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
            ),
          ),
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
      backgroundColor: Colors.white,
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
              style: TextStyle(
                fontSize: 15,
                color: context.sac.textSecondary,
              ),
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

    // Resolve category name
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ── Dark Header ────────────────────────────────────────
          _DarkHeader(
            honor: honor,
            categoryName: categoryName,
          ),

          // ── Body ───────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (honor.description != null &&
                      honor.description!.isNotEmpty) ...[
                    Text(
                      honor.description!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.7,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Material download card
                  if (honor.materialUrl != null &&
                      honor.materialUrl!.isNotEmpty) ...[
                    _MaterialCard(materialUrl: honor.materialUrl!),
                    const SizedBox(height: 24),
                  ],

                  // How it works section
                  _HowItWorksSection(),
                  const SizedBox(height: 28),

                  // CTA button — reactive to enrollment state
                  if (userHonorsLoading)
                    _EnrollCtaLoading()
                  else if (userHonor != null)
                    // Already enrolled — show requisitos section + evidence CTA
                    _EnrolledSection(
                      userHonor: userHonor,
                      honor: honor,
                    )
                  else
                    enrollAsync.when(
                      data: (enrolled) {
                        if (enrolled != null) {
                          // Just enrolled this session — navigate back
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              ref.invalidate(userHonorsProvider);
                              ref.invalidate(
                                  userHonorForHonorProvider(honorId));
                              context.pop();
                            }
                          });
                          return const SizedBox.shrink();
                        }
                        return _EnrollCta(
                          honorId: honorId,
                        );
                      },
                      loading: () => _EnrollCtaLoading(),
                      error: (err, _) => _EnrollCtaError(
                        message: err.toString(),
                        honorId: honorId,
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

// ── Dark Header ────────────────────────────────────────────────────────────────

class _DarkHeader extends StatelessWidget {
  final Honor honor;
  final String? categoryName;

  const _DarkHeader({required this.honor, this.categoryName});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sacBlack,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back arrow + category breadcrumb row
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.pop();
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(right: 12, top: 4, bottom: 4),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  if (categoryName != null)
                    Text(
                      categoryName!,
                      style: const TextStyle(
                        color: Color(0x99FFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Icon + name + pills row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 68px icon
                  _HonorIcon(honor: honor),
                  const SizedBox(width: 16),

                  // Name + pills
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          honor.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (honor.skillLevel != null)
                              _HeaderPill(
                                label: _skillLevelLabel(honor.skillLevel!),
                                background: Colors.white.withValues(alpha: 0.12),
                                textColor: Colors.white.withValues(alpha: 0.85),
                              ),
                            _HeaderPill(
                              label: _approvalLabel(honor.approval),
                              background:
                                  AppColors.sacGreen.withValues(alpha: 0.20),
                              textColor: AppColors.sacGreen,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HonorIcon extends StatelessWidget {
  final Honor honor;

  const _HonorIcon({required this.honor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: honor.imageUrl != null && honor.imageUrl!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: honor.imageUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, __, ___) => HugeIcon(
                  icon: HugeIcons.strokeRoundedAward01,
                  size: 34,
                  color: Colors.white,
                ),
              ),
            )
          : HugeIcon(
              icon: HugeIcons.strokeRoundedAward01,
              size: 34,
              color: Colors.white,
            ),
    );
  }
}

class _HeaderPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color textColor;

  const _HeaderPill({
    required this.label,
    required this.background,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Material Card ─────────────────────────────────────────────────────────────

class _MaterialCard extends StatefulWidget {
  final String materialUrl;

  const _MaterialCard({required this.materialUrl});

  @override
  State<_MaterialCard> createState() => _MaterialCardState();
}

class _MaterialCardState extends State<_MaterialCard> {
  bool _isLaunching = false;

  Future<void> _openMaterial() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);

    try {
      final uri = Uri.tryParse(widget.materialUrl);
      if (uri == null || !['http', 'https'].contains(uri.scheme)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo abrir el material'),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
      final canLaunch = await canLaunchUrl(uri);
      if (canLaunch) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No se pudo abrir el material'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Error al abrir el material PDF'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openMaterial,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F8FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // PDF icon in blue square
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.sacBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Text
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Material de estudio',
                    style: TextStyle(
                      color: AppColors.sacBlack,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'PDF — descargá para completar offline',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            // Download arrow
            if (_isLaunching)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: AppColors.sacBlue,
                  strokeWidth: 2,
                ),
              )
            else
              const Icon(
                Icons.download_rounded,
                color: AppColors.sacBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ── How It Works Section ──────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  static const _steps = [
    'Descargá el material y completalo con tu instructor',
    'Escaneá o fotografiá las hojas firmadas',
    'Subí la evidencia y enviala a revisión',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '¿Cómo funciona?',
          style: TextStyle(
            color: AppColors.sacBlack,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          children: List.generate(_steps.length, (i) {
            return Padding(
              padding: EdgeInsets.only(bottom: i < _steps.length - 1 ? 10 : 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Numbered circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.sacBlue,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Step text
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        _steps[i],
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── CTA Widgets ───────────────────────────────────────────────────────────────

class _EnrollCta extends ConsumerWidget {
  final int honorId;

  const _EnrollCta({required this.honorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sacGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final authState = ref.read(authNotifierProvider);
          final userId = authState.value?.id;
          if (userId == null) return;
          await ref
              .read(honorEnrollmentNotifierProvider.notifier)
              .enrollInHonor(userId, honorId);
        },
        child: const Text(
          'Inscribirme',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EnrollCtaLoading extends StatelessWidget {
  const _EnrollCtaLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sacGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: null,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }
}

class _EnrollCtaError extends ConsumerWidget {
  final String message;
  final int honorId;

  const _EnrollCtaError({required this.message, required this.honorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            message.replaceAll('Exception: ', ''),
            style: const TextStyle(
              color: AppColors.errorDark,
              fontSize: 12,
            ),
          ),
        ),
        _EnrollCta(honorId: honorId),
      ],
    );
  }
}

class _EnrolledCta extends StatelessWidget {
  final VoidCallback onTap;

  const _EnrolledCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.sacBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: onTap,
        child: const Text(
          'Ver mi progreso',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Enrolled Section (Requisitos + Evidence CTA) ───────────────────────────

/// Muestra la sección de requisitos y el botón de evidencia para usuarios inscritos.
/// La sección de requisitos solo aparece para usuarios enrollados (ya inscriptos).
class _EnrolledSection extends ConsumerWidget {
  final UserHonor userHonor;
  final Honor honor;

  const _EnrolledSection({
    required this.userHonor,
    required this.honor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final userId = authState.value?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Requisitos CTA ─────────────────────────────────────────────
        if (userId != null)
          _RequisitosCta(
            userId: userId,
            honorId: honor.id,
            userHonorId: userHonor.id,
            honorName: honor.name,
          ),
        if (userId != null) const SizedBox(height: 16),

        // ── Evidence / Progress CTA ────────────────────────────────────
        _EnrolledCta(
          onTap: () => context.push(
            RouteNames.honorEvidencePath(
              honor.id.toString(),
              userHonor.id.toString(),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Requisitos CTA ─────────────────────────────────────────────────────────

/// Card de requisitos para usuarios inscritos.
/// Muestra "X/Y completados" y una barra de progreso.
/// Al tocar navega a HonorRequirementsView.
class _RequisitosCta extends ConsumerWidget {
  final String userId;
  final int honorId;
  final int userHonorId;
  final String honorName;

  const _RequisitosCta({
    required this.userId,
    required this.honorId,
    required this.userHonorId,
    required this.honorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(userHonorProgressProvider(honorId));

    return progressAsync.when(
      data: (progressList) {
        final total = progressList.length;
        final completed = progressList.where((p) => p.completed).length;
        final percentage =
            total > 0 ? (completed / total).clamp(0.0, 1.0) : 0.0;

        return GestureDetector(
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
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.sacBlue.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icono en cuadro azul
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.sacBlue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.checklist_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Texto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Requisitos',
                            style: TextStyle(
                              color: AppColors.sacBlack,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            total == 0
                                ? 'Cargando requisitos...'
                                : '$completed/$total completados',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Flecha
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.sacBlue,
                      size: 16,
                    ),
                  ],
                ),

                // Barra de progreso
                if (total > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 5,
                      backgroundColor:
                          AppColors.sacBlue.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.sacBlue,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => _RequisitosCta._loadingShimmer(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  static Widget _loadingShimmer() {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0x2D3085FF),
          width: 1,
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE2E8F0),
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 11,
                  width: 80,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                SizedBox(
                  height: 9,
                  width: 120,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
