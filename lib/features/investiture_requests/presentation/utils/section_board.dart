import 'package:flutter/widgets.dart';

import '../../domain/entities/investiture_request.dart';
import '../../domain/entities/presentation_context.dart';

/// Reparto de la sección en los tres grupos del tablero de la directiva.
class SectionBoard {
  const SectionBoard({
    required this.ready,
    required this.waiting,
    required this.notYet,
  });

  /// Cumplen y pueden enviarse a autorización.
  final List<PresentationCandidate> ready;

  /// Ya enviadas y esperando al autorizador.
  final List<RequestPerson> waiting;

  /// Aún no cumplen; las más avanzadas primero.
  final List<PresentationCandidate> notYet;

  int get total => ready.length + waiting.length + notYet.length;
  bool get isEmpty => total == 0;
}

SectionBoard partitionSectionBoard(
  PresentationContext ctx,
  InvestitureRequest? request,
) {
  final ready = ctx.candidates
      .where((c) => c.eligible && c.pendingPersonId == null)
      .toList(growable: false);
  final notYet = ctx.candidates
      .where((c) => !c.eligible && c.pendingPersonId == null)
      .toList()
    ..sort((a, b) => b.overallProgress.compareTo(a.overallProgress));
  return SectionBoard(
    ready: ready,
    waiting: request?.pendingPeople ?? const [],
    notYet: notYet,
  );
}

/// Iniciales para el avatar ("Ana Pérez" → "AP").
String investitureInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  final first = parts.first.characters.first;
  final second = parts.length > 1 ? parts.last.characters.first : '';
  return '$first$second'.toUpperCase();
}
