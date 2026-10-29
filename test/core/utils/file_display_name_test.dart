import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/core/utils/file_display_name.dart';

void main() {
  group('meaningfulFileName', () {
    test('hides names the phone made up', () {
      for (final name in [
        'image_picker_E1F03742-B4FC-4A4B-9E0D-8F0A1B2C3D4E.jpg',
        'scaled_image_picker_E1F03742-B4FC-4A4B-9E0D-8F0A1B2C3D4E.jpg',
        'E1F03742-B4FC-4A4B-9E0D-8F0A1B2C3D4E.jpg',
        '   ',
        '',
      ]) {
        expect(meaningfulFileName(name), isNull, reason: name);
      }
    });

    test('keeps a real name, trimmed', () {
      expect(meaningfulFileName(' Ficha Lucia.pdf '), 'Ficha Lucia.pdf');
      expect(meaningfulFileName('IMG_1234.JPG'), 'IMG_1234.JPG');
    });
  });
}
