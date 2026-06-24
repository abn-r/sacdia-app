import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('profile photo preview keeps a visible size', () {
    final source = File(
      'lib/features/post_registration/presentation/widgets/profile_photo_picker.dart',
    ).readAsStringSync();

    expect(source, contains('width: 200,'));
    expect(source, isNot(contains('width: 00,')));
  });
}
