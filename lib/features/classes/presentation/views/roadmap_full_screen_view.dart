import 'package:flutter/material.dart';
import '../roadmap/widgets/roadmap_screen_connected.dart';

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
/// [extendBodyBehindAppBar] se omite (valor por defecto: false) para que el
/// body empiece limpiamente debajo de la AppBar y el primer track header no
/// quede oculto detrás del título "Mi Camino".
class RoadmapFullScreenView extends StatelessWidget {
  const RoadmapFullScreenView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Camino'),
        backgroundColor: colorScheme.surface,
        // automaticallyImplyLeading: true (default) provee el botón back via GoRouter.
      ),
      body: const RoadmapScreenConnected(),
    );
  }
}
