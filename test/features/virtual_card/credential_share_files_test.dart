import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/presentation/utils/credential_share_files.dart';

/// S6 (re-verify 2b): los archivos temporales de la credencial compartida se
/// borran tras compartir.

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('cred_share_test'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File make(String name) => File('${dir.path}/$name')..writeAsBytesSync([1]);

  test('deletes the shared files and tolerates one that is already gone',
      () async {
    final png = make('credencial_F1.png');
    final pdf = make('credencial_F1.pdf');
    final missing = File('${dir.path}/credencial_F1_missing.png');

    await deleteCredentialShareFiles([png, pdf, missing]);

    expect(png.existsSync(), isFalse);
    expect(pdf.existsSync(), isFalse);
  });

  test('honours the grace period before deleting', () async {
    final png = make('credencial_F2.png');

    final pending = deleteCredentialShareFiles(
      [png],
      grace: const Duration(milliseconds: 80),
    );
    expect(png.existsSync(), isTrue, reason: 'still alive for the recipient');
    await pending;

    expect(png.existsSync(), isFalse);
  });

  test('the sweep removes stale credential files and nothing else', () async {
    final stalePng = make('credencial_OLD.png');
    final stalePdf = make('credencial_OLD.pdf');
    final other = make('report.pdf');
    final otherPng = make('photo.png');

    await sweepCredentialShareFiles(dir);

    expect(stalePng.existsSync(), isFalse);
    expect(stalePdf.existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    expect(otherPng.existsSync(), isTrue);
  });

  test('sweeping a missing directory does not throw', () async {
    await sweepCredentialShareFiles(Directory('${dir.path}/nope'));
  });
}
