import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/user_honor.dart';

extension UserHonorPresentationX on UserHonor {
  /// Color for the current display status (use for border-left, badges, headers).
  Color get statusColor {
    switch (displayStatus) {
      case 'validado':
        return AppColors.success;
      case 'enviado':
        return AppColors.accent;
      case 'en_progreso':
      case 'rechazado':
        return AppColors.error;
      case 'inscrito':
        return AppColors.info;
      default:
        return AppColors.pendingColor;
    }
  }

  /// Human-readable label for the current display status.
  String get statusLabel {
    switch (displayStatus) {
      case 'validado':
        return tr('honors.user_status.validated');
      case 'enviado':
        return tr('honors.user_status.submitted');
      case 'en_progreso':
        return tr('honors.user_status.in_progress');
      case 'rechazado':
        return tr('honors.user_status.rejected');
      case 'inscrito':
        return tr('honors.user_status.enrolled');
      default:
        return tr('honors.user_status.available');
    }
  }
}
