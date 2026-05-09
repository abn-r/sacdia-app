import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../../../core/widgets/secure_screen.dart';
import 'credencial_tokens.dart';
import 'credencial_view_model.dart';
import 'live_clock.dart';
import 'verified_dot.dart';

/// QR a pantalla completa para presentar a checador.
///
/// - Fondo blanco puro, QR grande centrado.
/// - Reloj vivo + dot verificado (anti-screenshot).
/// - Sube brillo al máximo al entrar y restaura al salir.
class CredencialQrFullscreen extends StatefulWidget {
  final CredencialViewModel vm;

  /// Hero tag para la transición desde la tarjeta principal.
  /// Por convención usa 'virtual-card-qr-{userId}'.
  final String heroTag;

  const CredencialQrFullscreen({
    super.key,
    required this.vm,
    this.heroTag = 'credencial-qr-fullscreen',
  });

  @override
  State<CredencialQrFullscreen> createState() => _CredencialQrFullscreenState();
}

class _CredencialQrFullscreenState extends State<CredencialQrFullscreen> {
  double? _previousBrightness;
  final _qrBoundaryKey = GlobalKey();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    _setMaxBrightness();
  }

  Future<void> _setMaxBrightness() async {
    try {
      _previousBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {
      // Plataforma no soporta o falla silenciosa — no bloquear UI
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
      // Si reset falla, intentar restaurar valor previo
      try {
        if (_previousBrightness != null) {
          await ScreenBrightness().setApplicationScreenBrightness(
            _previousBrightness!,
          );
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _restoreBrightness();
    super.dispose();
  }

  Future<void> _saveQrToGallery() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('QR boundary no encontrado');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('No se pudo codificar PNG');
      }
      final bytes = byteData.buffer.asUint8List();

      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          throw StateError('Permiso de galería denegado');
        }
      }

      final safeFolio = widget.vm.folio.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        name: 'sacdia_qr_$safeFolio',
      );

      messenger.showSnackBar(
        const SnackBar(
          content: Text('QR guardado en galería'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('No se pudo guardar: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sec = Sec.of(widget.vm.seccion);
    final size = MediaQuery.of(context).size.shortestSide * 0.78;

    return SecureScreen(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Header
                Row(
                  children: [
                    Image.asset(sec.logo, width: 32, height: 32),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.vm.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CredencialTokens.textPrimaryLight,
                            ),
                          ),
                          Text(
                            sec.name,
                            style: TextStyle(
                              fontSize: 12,
                              color: sec.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Spacer(),
                // QR grande con Hero para transición desde la tarjeta.
                // Long-press → guarda PNG en galería del dispositivo.
                GestureDetector(
                  onLongPress: _saving ? null : _saveQrToGallery,
                  child: Hero(
                    tag: widget.heroTag,
                    transitionOnUserGestures: true,
                    child: RepaintBoundary(
                      key: _qrBoundaryKey,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 30,
                              offset: const Offset(0, 12),
                              color: sec.primary.withAlpha(0x26), // ~15%
                            ),
                          ],
                        ),
                        child: QrImageView(
                          data: widget.vm.qrData,
                          size: size,
                          backgroundColor: Colors.white,
                          eyeStyle: QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: sec.primaryDark,
                          ),
                          dataModuleStyle: QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: sec.primaryDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _saving ? 'Guardando…' : 'Mantén presionado para guardar',
                  style: TextStyle(
                    fontSize: 11,
                    color: CredencialTokens.textTertiaryLight,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.vm.folio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: CredencialTokens.textTertiaryLight,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Anti-screenshot indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1FBF4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFCEEBD7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const VerifiedDot(color: Color(0xFF22C55E)),
                      const SizedBox(width: 8),
                      const Text(
                        'VERIFICADO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: CredencialTokens.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const LiveClock(
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: CredencialTokens.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        ' MX',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: CredencialTokens.success.withAlpha(
                            0xB3,
                          ), // ~70%
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
