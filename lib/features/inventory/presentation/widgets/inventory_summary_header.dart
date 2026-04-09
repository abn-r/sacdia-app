import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/sac_colors.dart';
import '../../../../core/utils/icon_helper.dart';
import '../providers/inventory_providers.dart';

// ── Compact stats row ───────────────────────────────────────────────────────────

/// Fila compacta de estadísticas del inventario.
///
/// Muestra tres chips: total de ítems, valor estimado y un mini anillo
/// de salud basado en la proporción de ítems en buen estado.
/// Altura máxima: ~80px.
class InventoryStatsRow extends StatelessWidget {
  final InventorySummary summary;

  const InventoryStatsRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;
    final healthRatio = summary.totalItems > 0
        ? summary.buenoCount / summary.totalItems
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          // Total items chip
          _StatChip(
            icon: HugeIcons.strokeRoundedPackage,
            value: summary.totalItems.toString(),
            label: 'artículos',
            iconColor: AppColors.primary,
            bgColor: AppColors.primarySurface,
            borderColor: AppColors.primary.withValues(alpha: 0.25),
          ),
          const SizedBox(width: 8),

          // Value chip — only when there's data
          if (summary.totalValue > 0) ...[
            _StatChip(
              icon: HugeIcons.strokeRoundedMoney01,
              value: '\$${_formatValue(summary.totalValue)}',
              label: 'valor est.',
              iconColor: AppColors.accent,
              bgColor: AppColors.accent.withValues(alpha: 0.10),
              borderColor: AppColors.accent.withValues(alpha: 0.30),
            ),
            const SizedBox(width: 8),
          ],

          // Health ring chip
          _HealthRingChip(
            ratio: healthRatio,
            buenoCount: summary.buenoCount,
            totalItems: summary.totalItems,
            c: c,
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatChip extends StatefulWidget {
  final HugeIconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });

  @override
  State<_StatChip> createState() => _StatChipState();
}

class _StatChipState extends State<_StatChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
          border: Border.all(color: widget.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: widget.icon, size: 16, color: widget.iconColor),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.value,
                  style: TextStyle(
                    color: widget.iconColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.1,
                  ),
                ),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.iconColor.withValues(alpha: 0.7),
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRingChip extends StatelessWidget {
  final double ratio;
  final int buenoCount;
  final int totalItems;
  final SacColors c;

  const _HealthRingChip({
    required this.ratio,
    required this.buenoCount,
    required this.totalItems,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).round();
    final ringColor = ratio >= 0.8
        ? AppColors.secondary
        : ratio >= 0.5
            ? AppColors.accent
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: ringColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: ringColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CustomPaint(
              painter: _RingPainter(
                ratio: ratio,
                color: ringColor,
                trackColor: ringColor.withValues(alpha: 0.18),
              ),
              child: Center(
                child: Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.w800,
                    color: ringColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$buenoCount/$totalItems',
                style: TextStyle(
                  color: ringColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1.1,
                ),
              ),
              Text(
                'en buen estado',
                style: TextStyle(
                  color: ringColor.withValues(alpha: 0.7),
                  fontSize: 9,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Painter del mini anillo de salud.
class _RingPainter extends CustomPainter {
  final double ratio;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.ratio,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 2.5;
    const strokeWidth = 3.5;

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);

    // Progress arc
    if (ratio > 0) {
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: radius),
        -math.pi / 2,
        ratio * 2 * math.pi,
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.ratio != ratio || old.color != color;
}

// ── Filter bar (unchanged API) ──────────────────────────────────────────────────

/// Widget de barra de búsqueda + botón de filtros para el inventario.
class InventoryFilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final bool hasActiveFilters;

  const InventoryFilterBar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.hasActiveFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar artículos...',
                hintStyle:
                    TextStyle(color: context.sac.textTertiary, fontSize: 14),
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(12),
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedSearch01,
                    size: 18,
                    color: context.sac.textTertiary,
                  ),
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 16,
                          color: context.sac.textTertiary,
                        ),
                      )
                    : null,
                filled: true,
                fillColor: context.sac.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.sac.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterButton(
            onTap: onFilterTap,
            hasActiveFilters: hasActiveFilters,
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool hasActiveFilters;

  const _FilterButton({required this.onTap, required this.hasActiveFilters});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: hasActiveFilters
              ? AppColors.primarySurface
              : context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasActiveFilters ? AppColors.primary : context.sac.border,
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedFilter,
                size: 20,
                color: hasActiveFilters
                    ? AppColors.primary
                    : context.sac.textSecondary,
              ),
            ),
            if (hasActiveFilters)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Category chips (inline, horizontal scroll) ──────────────────────────────────

/// Barra de chips de categoría con scroll horizontal.
///
/// Siempre visible debajo del search bar — reemplaza el panel de categorías
/// del filter sheet. Chip "Todas" siempre primero.
class InventoryCategoryChips extends ConsumerWidget {
  const InventoryCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(inventoryCategoriesProvider);
    final filters = ref.watch(inventoryFiltersProvider);

    return SizedBox(
      height: 40,
      child: categoriesAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (cats) => ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: cats.length + 1, // +1 for "Todas"
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            if (index == 0) {
              final isSelected = filters.categoryId == null;
              return _CategoryChip(
                label: 'Todas',
                isSelected: isSelected,
                onTap: () {
                  ref.read(inventoryFiltersProvider.notifier).state =
                      filters.copyWith(clearCategory: true);
                },
              );
            }
            final cat = cats[index - 1];
            final isSelected = filters.categoryId == cat.id;
            return _CategoryChip(
              label: cat.name,
              isSelected: isSelected,
              onTap: () {
                ref.read(inventoryFiltersProvider.notifier).state =
                    filters.copyWith(categoryId: cat.id);
              },
            );
          },
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : context.sac.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.sac.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : context.sac.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
