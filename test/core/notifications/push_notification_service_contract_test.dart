import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'push notification tap navigation uses GoRouter, not Navigator.pushNamed',
    () {
      final source = File(
        'lib/core/notifications/push_notification_service.dart',
      ).readAsStringSync();

      expect(source, contains("package:go_router/go_router.dart"));
      expect(source, isNot(contains('.pushNamed(')));
    },
  );
}
