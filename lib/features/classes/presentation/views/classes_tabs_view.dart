import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/app_colors.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import '../roadmap/widgets/roadmap_screen_connected.dart';
import 'classes_list_view.dart';

/// Contenedor principal del tab "Clases" en el bottom nav.
///
/// Muestra un selector segmentado en la parte superior que alterna entre:
///   - Tab 0: lista de clases del usuario (ClassesListView)
///   - Tab 1: roadmap visual serpenteante (RoadmapScreen)
///
/// No tiene AppBar propio — sigue siendo un tab del bottom nav.
/// La SafeArea la delega a cada vista hijo para mantener el mismo
/// comportamiento que tenía ClassesListView antes de este cambio.
enum _ClassesTab { list, roadmap }

class ClassesTabsView extends StatefulWidget {
  const ClassesTabsView({super.key});

  @override
  State<ClassesTabsView> createState() => _ClassesTabsViewState();
}

class _ClassesTabsViewState extends State<ClassesTabsView> {
  _ClassesTab _selected = _ClassesTab.list;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return Scaffold(
      backgroundColor: _selected == _ClassesTab.roadmap
          // El roadmap tiene su propio gradiente — fondo transparente para que
          // el Stack interno pinte desde el borde superior.
          ? Colors.transparent
          : c.background,
      body: SafeArea(
        // bottom: false porque ClassesListView y el bottom nav ya manejan eso
        bottom: false,
        child: Column(
          children: [
            // ── Selector segmentado ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<_ClassesTab>(
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.primaryLight,
                  selectedForegroundColor: AppColors.primary,
                  foregroundColor: c.textSecondary,
                  side: BorderSide(color: c.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
                segments: const [
                  ButtonSegment<_ClassesTab>(
                    value: _ClassesTab.list,
                    label: Text('Mis Clases'),
                    icon: Icon(Icons.school_outlined, size: 18),
                  ),
                  ButtonSegment<_ClassesTab>(
                    value: _ClassesTab.roadmap,
                    label: Text('Roadmap'),
                    icon: Icon(Icons.route_outlined, size: 18),
                  ),
                ],
                selected: {_selected},
                onSelectionChanged: (newSelection) {
                  setState(() => _selected = newSelection.first);
                },
              ),
            ),
            // ── Vista activa ──────────────────────────────────────────────
            Expanded(
              child: _selected == _ClassesTab.list
                  ? const ClassesListViewBody()
                  : const RoadmapScreenConnected(),
            ),
          ],
        ),
      ),
    );
  }
}
