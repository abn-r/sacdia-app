import 'package:flutter/material.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

import '../../widgets/experimental/quick_access_compact_grid.dart';

/// Experimental layout kept for future use (option C/D of the 2026-11 home
/// redesign). Not routed; see quick_access_layouts_preview_view_test.dart.
///
/// Muestra las opciones C ([QuickAccessCompactGrid]) y D
/// ([QuickAccessGroupedGrid]) una bajo la otra. No está registrada en el
/// router ni enlazada desde ninguna pantalla: existe para mantener las
/// maquetas compiladas y probadas hasta que se decida adoptarlas.
class QuickAccessLayoutsPreviewView extends StatelessWidget {
  const QuickAccessLayoutsPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.sac.background,
      appBar: const SacTopBar(title: 'Quick access layouts (C / D)'),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            QuickAccessCompactGrid(),
            SizedBox(height: 32),
            QuickAccessGroupedGrid(),
          ],
        ),
      ),
    );
  }
}
