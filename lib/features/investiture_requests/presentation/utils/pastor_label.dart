import 'package:easy_localization/easy_localization.dart';

import '../../domain/entities/investiture_request.dart';

/// Quién autoriza, en una frase corta: "Ptr. Samuel Ibarra" con uno,
/// "Ptr. Samuel Ibarra y 2 más" con varios. `null` si no hay ninguno (la UI usa
/// un texto genérico, sin nombre).
String? pastorLabel(List<InvestitureActor> authorizers) {
  final names = authorizers
      .map((a) => a.name.trim())
      .where((n) => n.isNotEmpty)
      .toList(growable: false);
  if (names.isEmpty) return null;
  if (names.length == 1) {
    return tr('investiture_requests.pastor.one', namedArgs: {'name': names[0]});
  }
  return tr(
    'investiture_requests.pastor.more',
    namedArgs: {'name': names[0], 'count': '${names.length - 1}'},
  );
}
