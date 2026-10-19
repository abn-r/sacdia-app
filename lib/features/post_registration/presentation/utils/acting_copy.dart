import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/acting_providers.dart';

/// Nombre de pila del menor mientras el tutor actúa por él, o `null` si no se
/// está actuando (el texto se queda en segunda persona).
///
/// Sin nombre disponible se usa `post_registration.acting.name_fallback` para
/// no volver a dirigirse al tutor como "tú".
String? actingCopyName(WidgetRef ref) {
  final dependent = ref.watch(actingDependentProvider);
  if (dependent == null) return null;
  final name = dependent.firstName?.trim();
  return (name != null && name.isNotEmpty)
      ? name
      : 'post_registration.acting.name_fallback'.tr();
}

/// Texto del post-registro: [key] tal cual cuando no se actúa; con
/// `<key>_acting` y el nombre del menor cuando se actúa (tercera persona).
String postRegistrationCopy(String key, {String? actingName}) {
  if (actingName == null) return key.tr();
  return '${key}_acting'.tr(namedArgs: {'name': actingName});
}
