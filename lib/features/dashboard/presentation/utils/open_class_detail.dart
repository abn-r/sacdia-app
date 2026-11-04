import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sacdia_app/core/config/route_names.dart';
import 'package:sacdia_app/features/classes/presentation/providers/classes_providers.dart';

/// Abre el mismo detalle de clase que abre la pestaña Clases para su clase
/// actual, llevando el id de inscripción cuando las clases del usuario ya
/// están cargadas.
///
/// Compartido por [CurrentClassCard] y [ClassHeroCard] para que ambas
/// tarjetas naveguen idéntico.
void openClassDetail(BuildContext context, WidgetRef ref, int classId) {
  final classes = ref.read(userClassesProvider).value;
  int? enrollmentId;
  if (classes != null) {
    for (final progressiveClass in classes) {
      if (progressiveClass.id == classId) {
        enrollmentId = progressiveClass.enrollmentId;
        break;
      }
    }
  }
  context.push(
    RouteNames.classDetailPath(
      classId.toString(),
      enrollmentId: enrollmentId,
    ),
  );
}
