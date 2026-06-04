import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transición de estado que llegó desde la notificación de maestrías.
enum MasterHonorChangeTransition {
  awarded,
  recovered,
  notCurrent,
}

@immutable
class MasterHonorModalEvent {
  final MasterHonorChangeTransition transition;
  final List<String> masterHonorIds;
  final List<String> masterHonorNames;

  const MasterHonorModalEvent({
    required this.transition,
    required this.masterHonorIds,
    required this.masterHonorNames,
  });

  bool get isPlural => masterHonorNames.length > 1;

  String get title => switch (transition) {
        MasterHonorChangeTransition.awarded when isPlural =>
          '¡Nuevas maestrías obtenidas!',
        MasterHonorChangeTransition.awarded => '¡Nueva maestría obtenida!',
        MasterHonorChangeTransition.recovered when isPlural =>
          'Maestrías vigentes nuevamente',
        MasterHonorChangeTransition.recovered => 'Maestría vigente nuevamente',
        MasterHonorChangeTransition.notCurrent when isPlural =>
          'Maestrías marcadas como No vigente',
        MasterHonorChangeTransition.notCurrent =>
          'Maestría marcada como No vigente',
      };

  String get body => switch (transition) {
        MasterHonorChangeTransition.awarded when isPlural => 'Has obtenido:',
        MasterHonorChangeTransition.awarded =>
          'Has obtenido la maestría ${masterHonorNames.first}.',
        MasterHonorChangeTransition.recovered when isPlural =>
          'Estas maestrías vuelven a estar vigentes en tu perfil:',
        MasterHonorChangeTransition.recovered =>
          'La maestría ${masterHonorNames.first} vuelve a estar vigente en tu perfil.',
        MasterHonorChangeTransition.notCurrent when isPlural =>
          'Las validaciones requeridas para estas maestrías cambiaron. Actualmente no cumples con los requisitos, por lo que quedaron marcadas como No vigente.',
        MasterHonorChangeTransition.notCurrent =>
          'Las validaciones requeridas para la maestría ${masterHonorNames.first} cambiaron. Actualmente no cumples con los requisitos, por lo que quedó marcada como No vigente.',
      };
}

@immutable
class MasterHonorModalQueueState {
  final List<MasterHonorModalEvent> queue;
  final bool isShowingModal;

  const MasterHonorModalQueueState({
    this.queue = const <MasterHonorModalEvent>[],
    this.isShowingModal = false,
  });

  int get length => queue.length;
  bool get isEmpty => queue.isEmpty;
  MasterHonorModalEvent get single => queue.single;
  MasterHonorModalEvent? get firstOrNull => queue.isEmpty ? null : queue.first;

  MasterHonorModalQueueState copyWith({
    List<MasterHonorModalEvent>? queue,
    bool? isShowingModal,
  }) {
    return MasterHonorModalQueueState(
      queue: queue ?? this.queue,
      isShowingModal: isShowingModal ?? this.isShowingModal,
    );
  }
}

final masterHonorModalQueueProvider =
    NotifierProvider<MasterHonorModalQueueNotifier, MasterHonorModalQueueState>(
  MasterHonorModalQueueNotifier.new,
);

class MasterHonorModalQueueNotifier
    extends Notifier<MasterHonorModalQueueState> {
  @override
  MasterHonorModalQueueState build() => const MasterHonorModalQueueState();

  void enqueue(MasterHonorModalEvent event) {
    final names = event.masterHonorNames
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    if (names.isEmpty) return;

    final normalized = MasterHonorModalEvent(
      transition: event.transition,
      masterHonorIds: event.masterHonorIds,
      masterHonorNames: names,
    );

    state = state.copyWith(queue: [...state.queue, normalized]);
  }

  MasterHonorModalEvent? peekNext() => state.firstOrNull;

  void removeFirst() {
    if (state.queue.isEmpty) return;
    state = state.copyWith(queue: state.queue.sublist(1));
  }

  void markModalStarted() {
    state = state.copyWith(isShowingModal: true);
  }

  void markModalFinished() {
    state = state.copyWith(isShowingModal: false);
  }

  void clear() {
    state = const MasterHonorModalQueueState();
  }
}
