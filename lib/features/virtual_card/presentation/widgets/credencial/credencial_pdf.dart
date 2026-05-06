import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'credencial_tokens.dart';
import 'credencial_view_model.dart';

// ── Colour helpers ─────────────────────────────────────────────────────────────

PdfColor _pdfColor(int r, int g, int b) =>
    PdfColor.fromInt(0xFF000000 | (r << 16) | (g << 8) | b);

PdfColor _fromFlutterColor(int value) {
  final r = (value >> 16) & 0xFF;
  final g = (value >> 8) & 0xFF;
  final b = value & 0xFF;
  return _pdfColor(r, g, b);
}

// Section palette translated to PdfColor.
class _PdfPalette {
  final PdfColor primary;
  final PdfColor primaryDark;
  final PdfColor accent;

  const _PdfPalette({
    required this.primary,
    required this.primaryDark,
    required this.accent,
  });

  static _PdfPalette of(Sec sec) {
    return _PdfPalette(
      primary: _fromFlutterColor(sec.primary.toARGB32()),
      primaryDark: _fromFlutterColor(sec.primaryDark.toARGB32()),
      accent: _fromFlutterColor(sec.accent.toARGB32()),
    );
  }
}

// ── Date formatting ────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) {
  const meses = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];
  return '${d.day.toString().padLeft(2, '0')} ${meses[d.month - 1]} ${d.year}';
}

// ── Asset loader with graceful fallback ────────────────────────────────────────

Future<pw.ImageProvider?> _loadAssetImage(String assetPath) async {
  try {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    return pw.MemoryImage(bytes);
  } catch (_) {
    // Asset not available in test environment or path wrong — return null.
    return null;
  }
}

// ── Avatar loader with graceful fallback ──────────────────────────────────────

Future<pw.ImageProvider?> _loadAvatarImage(String? url) async {
  if (url == null || url.trim().isEmpty) return null;
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {'Accept': 'image/*'},
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
      return pw.MemoryImage(response.bodyBytes);
    }
  } catch (_) {
    // Network failure or timeout — fall back to initials gradient.
  }
  return null;
}

// ── Public entry point ────────────────────────────────────────────────────────

/// Builds a client-side PDF that visually mirrors [CredencialCard].
///
/// Uses A6 portrait (~105×148 mm) with 12pt margins.
/// Avatar image is fetched from [vm.fotoUrl] with a 5-second timeout;
/// if null, missing, or the fetch fails, an initials-gradient circle is
/// rendered instead (pure in-process, no network call).
///
/// Section logos are loaded from the Flutter asset bundle via [rootBundle].
/// If the asset is unavailable (e.g. test environment), the logo slot is
/// skipped gracefully so the rest of the PDF still renders correctly.
Future<Uint8List> buildCredencialPdf(CredencialViewModel vm) async {
  final sec = Sec.of(vm.seccion);
  final pal = _PdfPalette.of(sec);
  final doc = pw.Document();

  // Load assets in parallel.
  final logoFuture = _loadAssetImage(sec.logo);
  final avatarFuture = _loadAvatarImage(vm.fotoUrl);
  final logo = await logoFuture;
  final avatar = await avatarFuture;

  // Timestamp at PDF creation — not a live clock.
  final nowStr = DateFormat('HH:mm').format(DateTime.now());

  // ─── Derived display strings ───────────────────────────────────────────────
  final clubLabel =
      vm.clubLooksLikeAcronym && vm.sectionFull.isNotEmpty ? 'SECCIÓN' : 'CLUB';
  final clubValue = vm.clubLooksLikeAcronym && vm.sectionFull.isNotEmpty
      ? vm.sectionFull
      : vm.club;

  // Static PdfColors used repeatedly.
  const white = PdfColors.white;
  final grey = _pdfColor(0x6B, 0x72, 0x80);
  final greyLight = _pdfColor(0x9A, 0xA0, 0xAB);
  final borderLightColor = _pdfColor(0xEC, 0xEE, 0xF2);
  final dangerColor = _pdfColor(0xC8, 0x10, 0x2E);
  final successColor = _pdfColor(0x0E, 0x7C, 0x3A);

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a6,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context ctx) {
        return pw.Stack(
          children: [
            // ── Full-page gradient background ──────────────────────────────────
            pw.Positioned.fill(
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  gradient: pw.LinearGradient(
                    begin: pw.Alignment.topLeft,
                    end: pw.Alignment.bottomRight,
                    colors: [pal.primary, pal.primaryDark],
                    stops: const [0.0, 0.75],
                  ),
                  borderRadius: pw.BorderRadius.circular(24),
                ),
              ),
            ),

            // ── Decorative logo watermark (top-right, rotated, low opacity) ───
            if (logo != null)
              pw.Positioned(
                right: -40,
                top: -30,
                child: pw.Opacity(
                  opacity: 0.10,
                  child: pw.Transform.rotate(
                    angle: -0.21, // ~-12 degrees (radians)
                    child: pw.Image(logo, width: 200, height: 200),
                  ),
                ),
              ),

            // ── Main content column ────────────────────────────────────────────
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildTopRow(vm, sec, pal, logo, white),
                  pw.SizedBox(height: 8),
                  _buildIdentidad(vm, sec, pal, avatar, white),
                  pw.SizedBox(height: 0),
                  _buildZonaBlanca(
                    vm,
                    sec,
                    pal,
                    clubLabel,
                    clubValue,
                    nowStr,
                    grey,
                    greyLight,
                    borderLightColor,
                    dangerColor,
                    successColor,
                    white,
                  ),
                  if (vm.hasEmergencia) ...[
                    pw.SizedBox(height: 6),
                    _buildEmergencia(vm, dangerColor),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  return doc.save();
}

// ── Top row ───────────────────────────────────────────────────────────────────

pw.Widget _buildTopRow(
  CredencialViewModel vm,
  Sec sec,
  _PdfPalette pal,
  pw.ImageProvider? logo,
  PdfColor white,
) {
  final whiteAlpha = PdfColor.fromInt(0x2E000000 | 0x00FFFFFF); // ~18% white
  final whiteBorder = PdfColor.fromInt(0x40000000 | 0x00FFFFFF); // ~25% white
  final whiteText75 = PdfColor(1, 1, 1, 0.75);

  return pw.Row(
    children: [
      // Section logo
      if (logo != null)
        pw.Container(
          width: 28,
          height: 28,
          child: pw.Image(logo, fit: pw.BoxFit.contain),
        ),
      pw.SizedBox(width: 8),
      // Section name + motto
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              sec.name.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: white,
                letterSpacing: 0.5,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '"${sec.motto}"',
              style: pw.TextStyle(
                fontSize: 8,
                fontStyle: pw.FontStyle.italic,
                color: whiteText75,
              ),
            ),
          ],
        ),
      ),
      // VIGENTE / SUSPENDIDO pill
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(
          color: whiteAlpha,
          borderRadius: pw.BorderRadius.circular(999),
          border: pw.Border.all(color: whiteBorder, width: 0.5),
        ),
        child: pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            // Status dot
            pw.Container(
              width: 5,
              height: 5,
              decoration: pw.BoxDecoration(
                color: vm.estado == 'Activo'
                    ? PdfColor(0.09, 0.82, 0.39) // green-ish
                    : PdfColor(0.98, 0.16, 0.25), // red
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 4),
            pw.Text(
              vm.estado == 'Activo' ? 'VIGENTE' : 'SUSPENDIDO',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: white,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── Identity row ──────────────────────────────────────────────────────────────

pw.Widget _buildIdentidad(
  CredencialViewModel vm,
  Sec sec,
  _PdfPalette pal,
  pw.ImageProvider? avatar,
  PdfColor white,
) {
  final whiteRing = PdfColor(1, 1, 1, 0.30);
  final chipBg = PdfColor(1, 1, 1, 0.20);

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      // Avatar circle
      pw.Container(
        width: 60,
        height: 60,
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: whiteRing, width: 1.5),
        ),
        child: pw.ClipOval(
          child: avatar != null
              ? pw.Image(avatar, fit: pw.BoxFit.cover, width: 60, height: 60)
              : _buildInitialsCircle(vm, sec, pal),
        ),
      ),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Text(
              vm.nombre,
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: white,
              ),
              maxLines: 2,
            ),
            pw.SizedBox(height: 6),
            pw.Wrap(
              spacing: 4,
              runSpacing: 3,
              children: [
                if (vm.identidadPrimaria.isNotEmpty)
                  _buildChip(vm.identidadPrimaria, chipBg, white),
                if (vm.etapa.isNotEmpty)
                  _buildChip('Etapa ${vm.etapa}', chipBg, white)
                else if (vm.cargo.isNotEmpty &&
                    vm.sectionFull.isNotEmpty &&
                    vm.cargo.toLowerCase() != vm.sectionFull.toLowerCase())
                  _buildChip(vm.sectionFull, chipBg, white),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _buildInitialsCircle(
  CredencialViewModel vm,
  Sec sec,
  _PdfPalette pal,
) {
  return pw.Container(
    width: 60,
    height: 60,
    decoration: pw.BoxDecoration(
      gradient: pw.LinearGradient(
        begin: pw.Alignment.topLeft,
        end: pw.Alignment.bottomRight,
        colors: [pal.accent, pal.primary],
      ),
      shape: pw.BoxShape.circle,
    ),
    alignment: pw.Alignment.center,
    child: pw.Text(
      vm.iniciales,
      style: pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: pal.primaryDark,
      ),
    ),
  );
}

pw.Widget _buildChip(String label, PdfColor bg, PdfColor textColor) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: pw.BoxDecoration(
      color: bg,
      borderRadius: pw.BorderRadius.circular(999),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      ),
    ),
  );
}

// ── Zona blanca ───────────────────────────────────────────────────────────────

pw.Widget _buildZonaBlanca(
  CredencialViewModel vm,
  Sec sec,
  _PdfPalette pal,
  String clubLabel,
  String clubValue,
  String nowStr,
  PdfColor grey,
  PdfColor greyLight,
  PdfColor borderLightColor,
  PdfColor dangerColor,
  PdfColor successColor,
  PdfColor white,
) {
  final textDark = _pdfColor(0x0F, 0x11, 0x15);

  return pw.Container(
    decoration: pw.BoxDecoration(
      color: PdfColors.white,
      border: pw.Border(top: pw.BorderSide(color: pal.accent, width: 3)),
      borderRadius: const pw.BorderRadius.only(
        bottomLeft: pw.Radius.circular(16),
        bottomRight: pw.Radius.circular(16),
      ),
    ),
    padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // QR code block
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderLightColor, width: 0.5),
              ),
              child: vm.qrData.isNotEmpty
                  ? pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: vm.qrData,
                      width: 90,
                      height: 90,
                      color: pal.primaryDark,
                      drawText: false,
                    )
                  : pw.Container(
                      width: 90,
                      height: 90,
                      decoration: pw.BoxDecoration(
                        color: _pdfColor(0xF4, 0xF5, 0xF8),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          'QR',
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: _pdfColor(0x9A, 0xA0, 0xAB),
                          ),
                        ),
                      ),
                    ),
            ),
            pw.SizedBox(width: 10),
            // Right column: club label + 2×2 grid
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (clubValue.isNotEmpty) ...[
                    pw.Text(
                      clubLabel,
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.0,
                        color: grey,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      clubValue,
                      maxLines: 2,
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: textDark,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                  ],
                  // 2×2 mini-field grid
                  pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: 2.0,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                    children: [
                      _buildMiniField(
                        'VIGENTE',
                        _fmtDate(vm.fechaVencimiento),
                        grey,
                        textDark,
                        null,
                      ),
                      vm.tipoSangre.isNotEmpty
                          ? _buildMiniField(
                              'SANGRE',
                              vm.tipoSangre,
                              grey,
                              textDark,
                              dangerColor,
                            )
                          : _buildMiniField(
                              'SECCIÓN',
                              vm.seccion.name,
                              grey,
                              textDark,
                              null,
                            ),
                      _buildMiniField(
                        'AÑO ECL.',
                        vm.anioEclesiastico,
                        grey,
                        textDark,
                        null,
                      ),
                      _buildMiniField(
                        'ESTADO',
                        vm.estado,
                        grey,
                        textDark,
                        vm.estado == 'Activo' ? successColor : dangerColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        // Footer divider
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: borderLightColor, width: 0.5),
            ),
          ),
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Institution lines
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Iglesia Adventista del Séptimo Día',
                      style: pw.TextStyle(fontSize: 7, color: grey),
                    ),
                    pw.Text(
                      'Ministerio Juvenil',
                      style: pw.TextStyle(fontSize: 6.5, color: grey),
                    ),
                  ],
                ),
              ),
              // Right: sacdia.org + idCorto + folio + timestamp
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'sacdia.org',
                    style: pw.TextStyle(fontSize: 7, color: grey),
                  ),
                  pw.Text(
                    'v.${vm.idCorto}',
                    style: pw.TextStyle(fontSize: 6.5, color: greyLight),
                  ),
                ],
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                vm.folio,
                maxLines: 1,
                style: pw.TextStyle(fontSize: 7, color: greyLight),
              ),
            ),
            pw.Text(
              'PDF $nowStr MX',
              style: pw.TextStyle(fontSize: 7, color: greyLight),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildMiniField(
  String label,
  String value,
  PdfColor labelColor,
  PdfColor defaultValueColor,
  PdfColor? highlightColor,
) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 0.8,
          color: labelColor,
        ),
      ),
      pw.SizedBox(height: 1),
      pw.Text(
        value,
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: highlightColor ?? defaultValueColor,
        ),
      ),
    ],
  );
}

// ── Emergency contact block ────────────────────────────────────────────────────

pw.Widget _buildEmergencia(CredencialViewModel vm, PdfColor dangerColor) {
  final dangerBg = _pdfColor(0xFB, 0xE9, 0xEC);
  final dangerDark = _pdfColor(0x7A, 0x0A, 0x1C);
  final relacion = vm.emergenciaRelacion.isNotEmpty
      ? vm.emergenciaRelacion.toUpperCase()
      : 'CONTACTO';

  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: pw.BoxDecoration(
      color: dangerBg,
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: dangerColor, width: 0.5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'EMERGENCIA · $relacion',
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: dangerDark,
            letterSpacing: 0.8,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          vm.emergenciaNombre,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: dangerDark,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          vm.emergenciaTel,
          style: pw.TextStyle(fontSize: 8, color: dangerColor),
        ),
      ],
    ),
  );
}
