import '../../domain/entities/notification_preferences.dart';

/// Modelo de datos que mapea la respuesta JSON de
/// GET/PATCH /users/me/notification-preferences.
class NotificationPreferencesModel extends NotificationPreferences {
  const NotificationPreferencesModel({
    required super.master,
    required super.activities,
    required super.achievements,
    required super.approvals,
    required super.invitations,
    required super.reminders,
  });

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      master: json['master'] as bool? ?? true,
      activities: json['activities'] as bool? ?? true,
      achievements: json['achievements'] as bool? ?? true,
      approvals: json['approvals'] as bool? ?? true,
      invitations: json['invitations'] as bool? ?? true,
      reminders: json['reminders'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'master': master,
        'activities': activities,
        'achievements': achievements,
        'approvals': approvals,
        'invitations': invitations,
        'reminders': reminders,
      };

  factory NotificationPreferencesModel.fromEntity(
    NotificationPreferences entity,
  ) {
    return NotificationPreferencesModel(
      master: entity.master,
      activities: entity.activities,
      achievements: entity.achievements,
      approvals: entity.approvals,
      invitations: entity.invitations,
      reminders: entity.reminders,
    );
  }

  /// Serializa las preferencias a SharedPreferences (string values).
  Map<String, bool> toPrefsMap() => {
        'notif_push_master': master,
        'notif_push_activities': activities,
        'notif_push_achievements': achievements,
        'notif_push_approvals': approvals,
        'notif_push_invitations': invitations,
        'notif_push_reminders': reminders,
      };

  /// Reconstruye desde SharedPreferences.
  factory NotificationPreferencesModel.fromPrefsMap(
    Map<String, bool?> prefs,
  ) {
    return NotificationPreferencesModel(
      master: prefs['notif_push_master'] ?? true,
      activities: prefs['notif_push_activities'] ?? true,
      achievements: prefs['notif_push_achievements'] ?? true,
      approvals: prefs['notif_push_approvals'] ?? true,
      invitations: prefs['notif_push_invitations'] ?? true,
      reminders: prefs['notif_push_reminders'] ?? true,
    );
  }
}
