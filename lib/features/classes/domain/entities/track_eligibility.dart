import 'package:equatable/equatable.dart';

/// Estado de elegibilidad por track o para investidura.
class TrackEligibility extends Equatable {
  final bool? eligible;
  final bool? enabled;
  final String? reason;

  const TrackEligibility({
    this.eligible,
    this.enabled,
    this.reason,
  });

  factory TrackEligibility.fromJson(dynamic value) {
    if (value == null) return const TrackEligibility();

    if (value is bool) {
      return TrackEligibility(eligible: value);
    }

    if (value is Map) {
      return TrackEligibility(
        eligible: value['eligible'] as bool?,
        enabled: value['enabled'] as bool?,
        reason: value['reason']?.toString(),
      );
    }

    return const TrackEligibility();
  }

  Map<String, dynamic> toJson() => {
        if (eligible != null) 'eligible': eligible,
        if (enabled != null) 'enabled': enabled,
        if (reason != null) 'reason': reason,
      };

  /// Si llega explícitamente `eligible`, permite activar la condición.
  bool get isEligible => eligible == true;

  /// Si llega explícitamente `enabled`, habilita el estado del track.
  bool get isEnabled => enabled == true;

  @override
  List<Object?> get props => [eligible, enabled, reason];
}
