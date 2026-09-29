import 'package:easy_localization/easy_localization.dart';

import '../dashboard/domain/entities/dashboard_summary.dart';
import 'data/next_activity_widget_bridge.dart';
import 'domain/next_activity_widget_snapshot.dart';

Future<void> publishNextActivityWidget(DashboardSummary summary) {
  return NextActivityWidgetBridge.write(
    NextActivityWidgetSnapshot.fromSummary(
      summary,
      emptyTitle: tr('dashboard.activities.empty'),
      localeName: Intl.defaultLocale,
    ),
  );
}

Future<void> clearNextActivityWidget() {
  return NextActivityWidgetBridge.write(
    NextActivityWidgetSnapshot.empty(
      emptyTitle: tr('dashboard.activities.empty'),
    ),
  );
}
