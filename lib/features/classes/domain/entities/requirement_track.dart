import 'package:equatable/equatable.dart';

/// Tracks de requisitos de clase.
///
/// Mantiene compatibilidad backward: si el valor llega vacío o no reconocido
/// se conserva como [unknown] para evitar perder el dato en ordenamientos.
enum RequirementTrack { basic, advanced, extra, unknown }

/// Parsea el string del backend a enum.
class RequirementTrackMeta extends Equatable {
  final RequirementTrack track;

  const RequirementTrackMeta({required this.track});

  @override
  List<Object?> get props => [track];

  static RequirementTrack? fromValue(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().toUpperCase();
    switch (raw) {
      case 'BASIC':
        return RequirementTrack.basic;
      case 'ADVANCED':
        return RequirementTrack.advanced;
      case 'EXTRA':
        return RequirementTrack.extra;
      default:
        return null;
    }
  }

  /// i18n key for the track's section label.
  static String labelKey(RequirementTrack track) {
    switch (track) {
      case RequirementTrack.basic:
        return 'classes.detail_with_progress.track_basic';
      case RequirementTrack.advanced:
        return 'classes.detail_with_progress.track_advanced';
      case RequirementTrack.extra:
        return 'classes.detail_with_progress.track_extra';
      case RequirementTrack.unknown:
        return 'classes.detail_with_progress.track_unknown';
    }
  }

  static int sortWeight(RequirementTrack? track) {
    switch (track) {
      case RequirementTrack.basic:
        return 0;
      case RequirementTrack.advanced:
        return 1;
      case RequirementTrack.extra:
        return 2;
      case RequirementTrack.unknown:
      default:
        return 3;
    }
  }
}
