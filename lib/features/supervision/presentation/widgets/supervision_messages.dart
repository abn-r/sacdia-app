import 'package:easy_localization/easy_localization.dart';

/// The server's message for a failed action, or the generic error when it
/// sent none: an empty toast or an empty inline error helps nobody.
String supervisionErrorMessage(String? message) =>
    message == null || message.trim().isEmpty
        ? 'common.error_generic'.tr()
        : message;
