import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/utils/app_logger.dart';
import '../domain/next_activity_widget_snapshot.dart';

/// Escribe el resumen en el almacenamiento que leen los widgets nativos.
///
/// Claves compartidas con iOS (`UserDefaults`) y Android (`SharedPreferences`):
/// `activity_title`, `activity_day`, `activity_weekday`, `activity_month`,
/// `activity_time`, `activity_date`, `activity_club`, `activity_id`.
class NextActivityWidgetBridge {
  NextActivityWidgetBridge._();

  static const String appGroupId = 'group.com.sacdia.app';
  static const String androidProvider = 'NextActivityWidgetProvider';
  static const String qualifiedAndroidProvider =
      'com.sacdia.app.NextActivityWidgetProvider';
  static const String iosKind = 'NextActivityWidget';

  static int _ticket = 0;

  static Future<void> configure() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
    } on PlatformException catch (error) {
      AppLogger.w(
        'No se pudo configurar el grupo del widget',
        tag: 'NextActivityWidget',
        error: error,
      );
    }
  }

  static Future<void> write(NextActivityWidgetSnapshot snapshot) async {
    final ticket = ++_ticket;
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      if (ticket != _ticket) return;

      await Future.wait([
        HomeWidget.saveWidgetData<String>('activity_title', snapshot.title),
        HomeWidget.saveWidgetData<String>(
          'activity_date',
          snapshot.dateLabel,
        ),
        HomeWidget.saveWidgetData<String>('activity_weekday', snapshot.weekday),
        HomeWidget.saveWidgetData<String>('activity_day', snapshot.day),
        HomeWidget.saveWidgetData<String>('activity_month', snapshot.month),
        HomeWidget.saveWidgetData<String>('activity_time', snapshot.timeLabel),
        HomeWidget.saveWidgetData<String>('activity_club', snapshot.clubName),
        HomeWidget.saveWidgetData<String>(
          'activity_id',
          snapshot.activityId?.toString() ?? '',
        ),
      ]);
      if (ticket != _ticket) return;

      await HomeWidget.updateWidget(
        name: androidProvider,
        androidName: androidProvider,
        iOSName: iosKind,
        qualifiedAndroidName: qualifiedAndroidProvider,
      );
    } on PlatformException catch (error) {
      AppLogger.w(
        'No se pudo actualizar el widget de próxima actividad',
        tag: 'NextActivityWidget',
        error: error,
      );
    }
  }
}
