import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El QR de vinculación (`sacdia://pair?c=...`) solo abre la app si el esquema
/// está registrado en las dos plataformas. Estas pruebas leen la configuración
/// nativa porque un error ahí no lo detecta ningún test de Dart.
void main() {
  test('iOS registers the sacdia scheme and explains the camera use', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(plist, contains('<string>sacdia</string>'));
    // El esquema ya existente del login social sigue ahí.
    expect(plist, contains('<string>io.sacdia.app</string>'));
    final camera = RegExp(
      r'<key>NSCameraUsageDescription</key>\s*<string>([^<]+)</string>',
    ).firstMatch(plist)?.group(1);
    expect(camera, isNotNull);
    expect(camera!.toLowerCase(), contains('qr'));
  });

  test('Android handles sacdia://pair as a browsable VIEW intent', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(manifest,
        contains('<data android:scheme="sacdia" android:host="pair"/>'));
    expect(manifest, contains('android.intent.action.VIEW'));
    expect(manifest, contains('android.intent.category.BROWSABLE'));
    expect(manifest, contains('android.permission.CAMERA'));
  });
}
