import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_map_options_sheet.dart';

import '../../domain/entities/activity.dart';

Future<void> showActivityMapOptions(
  BuildContext context,
  Activity activity,
) {
  return showSacMapOptions(
    context,
    title: 'activities.widgets.open_location_title'.tr(),
    errorMessage: 'activities.widgets.map_open_error'.tr(),
    place: activity.activityPlace,
    lat: activity.lat,
    lng: activity.longitude,
  );
}
