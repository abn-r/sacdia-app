import 'dart:io';

import 'package:sacdia_app/core/constants/app_constants.dart';

void main() {
  try {
    AppConstants.resolveBaseUrl(
      override: Platform.environment[AppConstants.apiBaseUrlDefineKey] ?? '',
      isProduct: true,
    );
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 1;
  }
}
