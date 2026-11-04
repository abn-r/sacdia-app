import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/widgets/sac_skeleton.dart';

/// Skeleton de la carpeta de evidencias: un único [SacShimmer] sobre bloques
/// [SacSkeletonBox] (las tarjetas no llevan relleno propio: el shimmer pinta
/// todos los píxeles y taparía los bloques internos).
class EvidenceFolderLoadingSkeleton extends StatelessWidget {
  const EvidenceFolderLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SacShimmer(
      child: ExcludeSemantics(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // ── Header card skeleton ───────────────────────────────────────
            _buildHeaderCard(),
            const SizedBox(height: 10),

            // ── Progress summary row (3 stat pills) ────────────────────────
            _buildProgressSummaryRow(),
            const SizedBox(height: 16),

            // ── "Secciones" label ──────────────────────────────────────────
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SacSkeletonBox(width: 90, height: 16),
              ),
            ),

            // ── Section card skeletons (5 rows) ────────────────────────────
            ...List.generate(5, _buildSectionCard),
          ],
        ),
      ),
    );
  }

  // ── Header card ─────────────────────────────────────────────────────────────

  Widget _buildHeaderCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nombre + badge de estado
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: SacSkeletonBox(height: 15),
              ),
              const SizedBox(width: 10),
              SacSkeletonBox(width: 68, height: 24, radius: AppTheme.radiusLG),
            ],
          ),
          const SizedBox(height: 8),

          // Descripción (2 líneas)
          SacSkeletonBox(height: 12),
          const SizedBox(height: 5),
          SacSkeletonBox(width: 200, height: 12),

          const SizedBox(height: 14),
          SacSkeletonBox(height: 1, radius: 0),
          const SizedBox(height: 12),

          // Progress bar + porcentaje
          Row(
            children: [
              Expanded(
                child: SacSkeletonBox(height: 5, radius: AppTheme.radius2XS),
              ),
              const SizedBox(width: 10),
              SacSkeletonBox(width: 32, height: 12),
            ],
          ),
          const SizedBox(height: 10),

          // Puntos
          Row(
            children: [
              SacSkeletonBox(width: 13, height: 13, radius: AppTheme.radius2XS),
              const SizedBox(width: 5),
              SacSkeletonBox(width: 100, height: 12),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress summary row ─────────────────────────────────────────────────────

  Widget _buildProgressSummaryRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: List.generate(3, (i) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SacSkeletonBox(width: 24, height: 16),
                  const SizedBox(height: 4),
                  SacSkeletonBox(width: 54, height: 10),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Section card ─────────────────────────────────────────────────────────────

  Widget _buildSectionCard(int index) {
    final nameWidths = [160.0, 140.0, 180.0, 150.0, 170.0];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Container(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Ícono de sección
            SacSkeletonBox(width: 38, height: 38, radius: AppTheme.radiusXS),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SacSkeletonBox(
                      width: nameWidths[index % nameWidths.length], height: 14),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      SacSkeletonBox(width: 60, height: 11),
                      const SizedBox(width: 8),
                      SacSkeletonBox(
                          width: 50, height: 18, radius: AppTheme.radiusLG),
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            SacSkeletonBox(width: 16, height: 16, radius: AppTheme.radius2XS),
          ],
        ),
      ),
    );
  }
}
