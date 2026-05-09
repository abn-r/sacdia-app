import 'package:flutter/material.dart';
import 'classes_list_view.dart';

/// Contenedor del tab "Clases" en el bottom nav.
///
/// El selector segmentado fue eliminado — Mis Clases es el contenido primario
/// del tab y el Roadmap se accede como pantalla independiente desde el chip
/// dentro de [ClassesListView].
///
/// Este wrapper se mantiene para que el router no necesite cambios en
/// [RouteNames.homeClasses] ni en el [StatefulShellBranch] existente.
class ClassesTabsView extends StatelessWidget {
  const ClassesTabsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const ClassesListView();
  }
}
