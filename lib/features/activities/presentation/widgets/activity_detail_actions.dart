import '../../domain/entities/activity.dart';

/// The single primary action of the detail footer.
enum ActivityFooterAction { none, showMyQr, manageAttendance, joinMeeting }

/// Which action the footer offers.
///
/// - In-person / hybrid: staff with attendance permission get "Attendance"
///   (also once finished); members get "Show my QR" until it is finished.
/// - Virtual: "Join the meeting" while it has not finished and has a link.
///   Staff confirm attendance from a row of the attendance group instead.
ActivityFooterAction activityFooterAction(
  Activity activity,
  ActivityPhase phase, {
  required bool canManageAttendance,
}) {
  if (activity.platform == 1) {
    return activity.hasVirtualLink && phase != ActivityPhase.finished
        ? ActivityFooterAction.joinMeeting
        : ActivityFooterAction.none;
  }
  if (canManageAttendance) return ActivityFooterAction.manageAttendance;
  return phase == ActivityPhase.finished
      ? ActivityFooterAction.none
      : ActivityFooterAction.showMyQr;
}
