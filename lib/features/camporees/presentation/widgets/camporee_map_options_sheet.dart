import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_map_options_sheet.dart';

import '../../domain/entities/camporee.dart';

Future<void> showCamporeeMapOptions(
  BuildContext context,
  Camporee camporee,
) {
  return showSacMapOptions(
    context,
    title: 'camporees.detail.open_location_title'.tr(),
    errorMessage: 'camporees.detail.map_open_error'.tr(),
    place: camporee.place,
    lat: camporee.lat,
    lng: camporee.longitude,
  );
}
