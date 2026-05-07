import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_pdf.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_tokens.dart';
import 'package:sacdia_app/features/virtual_card/presentation/widgets/credencial/credencial_view_model.dart';

void main() {
  // rootBundle is required for the section logo asset load inside buildCredencialPdf.
  // TestWidgetsFlutterBinding wires up the asset path resolution so
  // rootBundle.load() works in tests (assets must still be declared in pubspec).
  // If the asset load fails (e.g. not in test bundle), _loadAssetImage returns
  // null gracefully and the PDF is still generated without the logo image.
  TestWidgetsFlutterBinding.ensureInitialized();

  CredencialViewModel buildVm({
    String seccion = 'CQ',
    bool hasEmergencia = false,
  }) {
    final seccionCode = switch (seccion) {
      'AV' => SeccionCode.AV,
      'GM' => SeccionCode.GM,
      _ => SeccionCode.CQ,
    };

    return CredencialViewModel(
      nombre: 'Juan Pérez Martínez',
      cargo: 'Director',
      etapa: '',
      club: 'Club Conquistadores del Norte',
      clubCorto: 'CCN',
      sectionFull: 'Conquistadores',
      qrData: 'eyJhbGciOiJIUzI1NiJ9.testpayload.signature12345678',
      folio: 'SAC-2026-ABCD-1234',
      idCorto: 'abcd1234',
      fechaVencimiento: DateTime.utc(2027, 1, 15),
      anioEclesiastico: '2026',
      estado: 'Activo',
      seccion: seccionCode,
      // fotoUrl intentionally null — no HTTP fetch will be attempted,
      // making the test purely synchronous after asset load.
      fotoUrl: null,
      tipoSangre: 'O+',
      emergenciaNombre: hasEmergencia ? 'Maria Lopez' : '',
      emergenciaTel: hasEmergencia ? '+5215512345678' : '',
      emergenciaRelacion: hasEmergencia ? 'Madre' : '',
    );
  }

  group('buildCredencialPdf', () {
    test('returns non-empty Uint8List for CQ section without avatar', () async {
      final vm = buildVm(seccion: 'CQ');
      final bytes = await buildCredencialPdf(vm);

      expect(bytes, isA<Uint8List>());
      expect(bytes.length, greaterThan(0));
    });

    test('first 4 bytes are the PDF magic header %PDF (0x25 0x50 0x44 0x46)',
        () async {
      final vm = buildVm(seccion: 'CQ');
      final bytes = await buildCredencialPdf(vm);

      // %PDF in ASCII
      expect(bytes[0], equals(0x25), reason: 'expected %');
      expect(bytes[1], equals(0x50), reason: 'expected P');
      expect(bytes[2], equals(0x44), reason: 'expected D');
      expect(bytes[3], equals(0x46), reason: 'expected F');
    });

    test('generates valid PDF for AV section', () async {
      final vm = buildVm(seccion: 'AV');
      final bytes = await buildCredencialPdf(vm);

      expect(bytes.length, greaterThan(100));
      expect(bytes[0], equals(0x25));
    });

    test('generates valid PDF for GM section', () async {
      final vm = buildVm(seccion: 'GM');
      final bytes = await buildCredencialPdf(vm);

      expect(bytes.length, greaterThan(100));
      expect(bytes[0], equals(0x25));
    });

    test('generates PDF with emergency contact block', () async {
      final vm = buildVm(seccion: 'CQ', hasEmergencia: true);
      // Emergency block should add some bytes (larger PDF than without).
      final withEmergencia = await buildCredencialPdf(vm);
      final withoutEmergencia = await buildCredencialPdf(buildVm());

      expect(withEmergencia.length, greaterThan(0));
      // Both are valid PDFs regardless of which is larger.
      expect(withEmergencia[0], equals(0x25));
      expect(withoutEmergencia[0], equals(0x25));
    });

    test('generates PDF when qrData is empty (no QR widget rendered)',
        () async {
      final vm = CredencialViewModel(
        nombre: 'Sin QR',
        cargo: 'Miembro',
        etapa: '',
        club: 'Club Test',
        clubCorto: 'CT',
        sectionFull: 'Conquistadores',
        qrData: '', // empty — forces the placeholder branch
        folio: 'SAC-2026-0000-0000',
        idCorto: '00000000',
        fechaVencimiento: DateTime.utc(2027, 1, 1),
        anioEclesiastico: '2026',
        estado: 'Suspendido',
        seccion: SeccionCode.CQ,
        fotoUrl: null,
      );

      final bytes = await buildCredencialPdf(vm);

      expect(bytes.length, greaterThan(0));
      expect(bytes[0], equals(0x25));
    });
  });
}
