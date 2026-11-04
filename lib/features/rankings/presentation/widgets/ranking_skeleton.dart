import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/sac_skeleton.dart';

/// Skeleton de contenido para pantallas de ranking.
///
/// Dos constructores de fábrica:
/// - [RankingSkeleton.myRanking] — layout de MyRankingScreen.
/// - [RankingSkeleton.sectionList] — lista de sección.
///
/// Usa el `SacShimmer` compartido (respeta reduce motion).
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

  /// Skeleton con la forma del scorecard de progreso anual.
  factory RankingSkeleton.annualProgress() =>
      const RankingSkeleton._(mode: _SkeletonMode.annualProgress);

  /// Skeleton con la forma de una lista de sección.
  factory RankingSkeleton.sectionList({int count = 8}) =>
      RankingSkeleton._(mode: _SkeletonMode.sectionList, rowCount: count);

  @override
  State<RankingSkeleton> createState() => _RankingSkeletonState();
}

enum _SkeletonMode { myRanking, annualProgress, sectionList }

class _RankingSkeletonState extends State<RankingSkeleton> {
  @override
  Widget build(BuildContext context) {
    // Un único SacShimmer sobre bloques SacSkeletonBox; el shimmer respeta
    // reduce motion por su cuenta.
    return SacShimmer(child: ExcludeSemantics(child: _buildContent()));
  }

  Widget _buildContent() {
    switch (widget._mode) {
      case _SkeletonMode.myRanking:
        return _buildMyRankingSkeleton();
      case _SkeletonMode.annualProgress:
        return _buildAnnualProgressSkeleton();
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

  Widget _buildAnnualProgressSkeleton() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero: puntos + track + escalera de rangos.
            _ShimmerBox(height: 252, borderRadius: AppTheme.radiusMD),
            const SizedBox(height: 12),
            // Desglose por ejes.
            _ShimmerBox(height: 296, borderRadius: AppTheme.radiusMD),
            const SizedBox(height: 12),
            // Pendientes.
            _ShimmerBox(height: 128, borderRadius: AppTheme.radiusMD),
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

/// Caja de skeleton con forma rectangular (ancho = fracción del disponible).
class _ShimmerBox extends StatelessWidget {
  final double height;
  final double borderRadius;
  final double widthFactor;

  const _ShimmerBox({
    required this.height,
    this.borderRadius = 8,
    this.widthFactor = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: SacSkeletonBox(height: height, radius: borderRadius),
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
        const SacSkeletonBox(width: 32, height: 32, radius: 16),
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
