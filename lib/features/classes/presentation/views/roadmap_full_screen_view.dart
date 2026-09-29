import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../roadmap/widgets/roadmap_screen_connected.dart';
import 'package:sacdia_app/core/widgets/sac_top_bar.dart';

/// Pantalla completa del Roadmap de Clases.
///
/// Provee el Scaffold con AppBar (flecha de retorno automática via GoRouter)
/// y renderiza [RoadmapScreenConnected] como contenido.
///
/// Se accede desde el chip "Ver mi camino completo" en [ClassesListView]
/// via context.push(RouteNames.homeClassesRoadmap).
/// El back-button retorna a Mis Clases con el estado preservado
/// (StatefulShellBranch mantiene el árbol de widgets vivo).
///
/// El contenido reserva el alto de la barra. La leyenda queda debajo del
/// título y el camino puede deslizarse hacia el blur.
class RoadmapFullScreenView extends StatelessWidget {
  const RoadmapFullScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SacTopBar(title: 'classes.roadmap.title'.tr(), frosted: true),
      body: SacFrostedVeil(
        child: Builder(
          builder: (context) => Padding(
            padding: EdgeInsets.only(top: SacTopBar.frostedInset(context)),
            child: const RoadmapScreenConnected(),
          ),
        ),
      ),
    );
  }
}
