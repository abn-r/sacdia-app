import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/sac_snack_bar.dart';

/// Opens a new mail to support; if no mail app can, says where to write.
Future<void> openSupportEmail(BuildContext context) async {
  final uri = Uri(
    scheme: 'mailto',
    path: AppConstants.supportEmail,
    queryParameters: {'subject': 'support.email_subject'.tr()},
  );
  var ok = false;
  try {
    if (await canLaunchUrl(uri)) {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // Falls through to the copy hint.
  }
  if (!ok && context.mounted) {
    SacSnackBar.show(
      context,
      'support.channel_launch_failed'.tr(args: [AppConstants.supportEmail]),
    );
  }
}

/// Copies the support address and confirms it.
Future<void> copySupportEmail(BuildContext context) async {
  await Clipboard.setData(
    const ClipboardData(text: AppConstants.supportEmail),
  );
  if (context.mounted) {
    SacSnackBar.show(context, 'support.contact_copied'.tr());
  }
}
