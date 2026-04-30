import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';

/// Skeleton de contenido para pantallas de ranking.
///
/// Dos constructores de fábrica:
/// - [RankingSkeleton.myRanking] — layout de MyRankingScreen.
/// - [RankingSkeleton.sectionList] — lista de sección.
///
/// Usa animación de opacidad simple para el efecto shimmer.
/// Respeta `MediaQuery.disableAnimations` para usuarios con
/// `prefers-reduced-motion` activado en el dispositivo.
class RankingSkeleton extends StatefulWidget {
  final _SkeletonMode _mode;
  final int _rowCount;

  const RankingSkeleton._({
    required _SkeletonMode mode,
    int rowCount = 8,
  })  : _mode = mode,
        _rowCount = rowCount;

  /// Skeleton con la forma de la pantalla "Mi Ranking":
  /// card hero oscura → 3 mini-cards → 8 filas de top-N.
  factory RankingSkeleton.myRanking() =>
      const RankingSkeleton._(mode: _SkeletonMode.myRanking);

  /// Skeleton con la forma de una lista de sección.
  factory RankingSkeleton.sectionList({int count = 8}) =>
      RankingSkeleton._(mode: _SkeletonMode.sectionList, rowCount: count);

  @override
  State<RankingSkeleton> createState() => _RankingSkeletonState();
}

enum _SkeletonMode { myRanking, sectionList }

class _RankingSkeletonState extends State<RankingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _opacity = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, _) {
        return Opacity(
          opacity: _opacity.value,
          child: _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    switch (widget._mode) {
      case _SkeletonMode.myRanking:
        return _buildMyRankingSkeleton();
      case _SkeletonMode.sectionList:
        return _buildSectionListSkeleton();
    }
  }

  Widget _buildMyRankingSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Hero card oscura ~120dp.
            _ShimmerBox(
              height: 120,
              color: AppColors.darkSurfaceVariant,
              borderRadius: AppTheme.radiusMD,
            ),

            const SizedBox(height: 12),

            // 3 mini-cards horizontales.
            Row(
              children: [
                Expanded(
                    child: _ShimmerBox(
                        height: 80, borderRadius: AppTheme.radiusMD)),
                const SizedBox(width: 8),
                Expanded(
                    child: _ShimmerBox(
                        height: 80, borderRadius: AppTheme.radiusMD)),
                const SizedBox(width: 8),
                Expanded(
                    child: _ShimmerBox(
                        height: 80, borderRadius: AppTheme.radiusMD)),
              ],
            ),

            const SizedBox(height: 20),

            // Línea de nudge.
            _ShimmerBox(height: 14, borderRadius: 4, widthFactor: 0.65),

            const SizedBox(height: 20),

            // Título "Tu sección".
            _ShimmerBox(height: 12, borderRadius: 4, widthFactor: 0.3),

            const SizedBox(height: 12),

            // Filas del top-N.
            ...List.generate(
              8,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SectionRowSkeleton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionListSkeleton() {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget._rowCount,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: _SectionRowSkeleton(),
      ),
    );
  }
}

/// Caja de shimmer con forma rectangular.
class _ShimmerBox extends StatelessWidget {
  final double height;
  final Color? color;
  final double borderRadius;
  final double widthFactor;

  const _ShimmerBox({
    required this.height,
    this.color,
    this.borderRadius = 8,
    this.widthFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: color ?? AppColors.lightSurfaceVariant,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Fila de skeleton para el listado de sección: circulo 32dp + 2 barras.
class _SectionRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Círculo izquierdo (posición / avatar).
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.lightSurfaceVariant,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),

        // Barra central (nombre).
        Expanded(
          child: _ShimmerBox(height: 12, borderRadius: 4),
        ),
        const SizedBox(width: 12),

        // Barra derecha (puntaje badge) — ancho fijo 48dp para evitar
        // excepción de eje horizontal no acotado con FractionallySizedBox.
        SizedBox(
          width: 48,
          child: _ShimmerBox(height: 24, borderRadius: 8),
        ),
      ],
    );
  }
}
