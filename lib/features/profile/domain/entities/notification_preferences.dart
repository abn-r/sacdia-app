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
