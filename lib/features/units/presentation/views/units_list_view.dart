import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_card.dart';

import '../../domain/entities/unit.dart';
import '../providers/units_providers.dart';
import 'unit_detail_view.dart';

/// Vista de lista de unidades disponibles para el usuario.
///
/// Si el usuario tiene exactamente una unidad, navega directamente
/// a [UnitDetailView] sin mostrar la lista (post-build callback).
///
/// Si tiene más de una, muestra la lista con animación stagger.
class UnitsListView extends ConsumerStatefulWidget {
  const UnitsListView({super.key});

  @override
  ConsumerState<UnitsListView> createState() => _UnitsListViewState();
}

class _UnitsListViewState extends ConsumerState<UnitsListView> {
  @override
  void initState() {
    super.initState();

    // Evaluar post-build para no causar un push durante el build tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final units = ref.read(unitsNotifierProvider).units;

      if (units.length == 1) {
        _navigateToUnit(units.first, replace: true);
      }
    });
  }

  void _navigateToUnit(Unit unit, {bool replace = false}) {
    final notifier = ref.read(unitsNotifierProvider.notifier);
    notifier.selectUnit(unit);

    final route = MaterialPageRoute<void>(
      builder: (_) => UnitDetailView(unit: unit),
    );

    if (replace) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(unitsNotifierProvider);
    final c = context.sac;

    // Caso de una sola unidad: render placeholder mientras se hace el push
    if (state.units.length == 1) {
      return Scaffold(
        backgroundColor: c.background,
        body: const Center(child: SizedBox.shrink()),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Mis Unidades'),
      ),
      body: state.units.isEmpty
          ? _EmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: state.units.length,
              itemBuilder: (context, index) {
                final unit = state.units[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SacCard(
                    animate: true,
                    animationDelay: Duration(milliseconds: index * 80),
                    onTap: () => _navigateToUnit(unit),
                    accentColor: AppColors.primary,
                    padding: const EdgeInsets.all(16),
                    child: _UnitCard(unit: unit),
                  ),
                );
              },
            ),
    );
  }
}

// ── Subwidgets ────────────────────────────────────────────────────────────────

class _UnitCard extends StatelessWidget {
  final Unit unit;

  const _UnitCard({required this.unit});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      children: [
        // Icono de unidad
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: 26,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unit.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: c.text,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _InfoChip(
                    icon: HugeIcons.strokeRoundedLabel,
                    label: unit.type,
                  ),
                  const SizedBox(width: 8),
                  _InfoChip(
                    icon: HugeIcons.strokeRoundedUser,
                    label: '${unit.memberCount} miembros',
                  ),
                ],
              ),
              if (unit.leaderName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedUserStar01,
                      size: 13,
                      color: c.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit.leaderName!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: c.textTertiary,
                          ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Chevron
        HugeIcon(
          icon: HugeIcons.strokeRoundedArrowRight01,
          size: 20,
          color: c.textTertiary,
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 12, color: c.textSecondary),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: c.textSecondary,
              ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedUserGroup,
            size: 64,
            color: c.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No tienes unidades asignadas',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: c.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contacta al director de tu club\npara que te asigne una unidad.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: c.textTertiary,
                ),
          ),
        ],
      ),
    );
  }
}
