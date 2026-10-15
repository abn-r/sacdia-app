import 'package:equatable/equatable.dart';

/// Preferencias de notificación push del usuario.
///
/// Refleja exactamente la respuesta de
/// GET /users/me/notification-preferences
/// y el body de PATCH /users/me/notification-preferences.
class NotificationPreferences extends Equatable {
  final bool master;
  final bool activities;
  final bool achievements;
  final bool approvals;
  final bool invitations;
  final bool reminders;

  const NotificationPreferences({
    required this.master,
    required this.activities,
    required this.achievements,
    required this.approvals,
    required this.invitations,
    required this.reminders,
  });

  /// Valores por defecto offline (todo habilitado).
  const NotificationPreferences.defaults()
      : master = true,
        activities = true,
        achievements = true,
        approvals = true,
        invitations = true,
        reminders = true;

  /// Whether push is on for at least one category.
  ///
  /// Use this for the master switch instead of [master]: the backend derives
  /// [master] as the AND of the categories, so one category off reports
  /// master=false even though push is still on for the rest.
  bool get anyCategoryEnabled =>
      activities || achievements || approvals || invitations || reminders;

  /// Applies a PATCH delta locally. `master` cascades to every category, the
  /// same way the backend applies it, so the optimistic state matches the
  /// server response.
  NotificationPreferences applyDelta(Map<String, bool> delta) {
    final cascade = delta['master'];
    final base = cascade == null
        ? this
        : NotificationPreferences(
            master: cascade,
            activities: cascade,
            achievements: cascade,
            approvals: cascade,
            invitations: cascade,
            reminders: cascade,
          );
    return base.copyWith(
      activities: delta['activities'],
      achievements: delta['achievements'],
      approvals: delta['approvals'],
      invitations: delta['invitations'],
      reminders: delta['reminders'],
    );
  }

  NotificationPreferences copyWith({
    bool? master,
    bool? activities,
    bool? achievements,
    bool? approvals,
    bool? invitations,
    bool? reminders,
  }) {
    return NotificationPreferences(
      master: master ?? this.master,
      activities: activities ?? this.activities,
      achievements: achievements ?? this.achievements,
      approvals: approvals ?? this.approvals,
      invitations: invitations ?? this.invitations,
      reminders: reminders ?? this.reminders,
    );
  }

  @override
  List<Object?> get props =>
      [master, activities, achievements, approvals, invitations, reminders];
}
