import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:sacdia_app/core/theme/app_theme.dart';
import 'package:sacdia_app/core/utils/app_logger.dart';
import 'package:sacdia_app/core/widgets/sac_button.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:sacdia_app/core/widgets/sac_snack_bar.dart';

import '../../../../../core/widgets/secure_screen.dart';
import 'credencial_tokens.dart';
import 'credencial_view_model.dart';
import 'live_clock.dart';
import 'verified_dot.dart';

/// The QR on its own, to be scanned at an activity. It opens over the whole
/// app (root navigator, no tab bar), raises the brightness and restores it on
/// the way out. The live clock proves it is not a screenshot.
class CredencialQrFullscreen extends StatefulWidget {
  const CredencialQrFullscreen({
    super.key,
    required this.vm,
    this.heroTag = 'credencial-qr-fullscreen',
  });

  final CredencialViewModel vm;

  /// Hero tag shared with the QR on the card ('virtual-card-qr-{userId}').
  final String heroTag;

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
    _setMaxBrightness();
  }

  Future<void> _setMaxBrightness() async {
    try {
      _previousBrightness = await ScreenBrightness().application;
      await ScreenBrightness().setApplicationScreenBrightness(1.0);
    } catch (_) {
      // The platform may not support it: never block the screen.
    }
  }

  Future<void> _restoreBrightness() async {
    try {
      await ScreenBrightness().resetApplicationScreenBrightness();
    } catch (_) {
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
        throw StateError('QR boundary not found');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        throw StateError('QR image could not be encoded');
      }

      final hasAccess = await Gal.hasAccess(toAlbum: false);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: false);
        if (!granted) {
          throw StateError('Photo library access denied');
        }
      }

      final safeFolio = widget.vm.folio.replaceAll(
        RegExp(r'[^A-Za-z0-9_-]'),
        '_',
      );
      await Gal.putImageBytes(
        byteData.buffer.asUint8List(),
        name: 'sacdia_qr_$safeFolio',
      );

      SacSnackBar.showMessenger(
        messenger,
        'virtual_card.qr_screen.saved'.tr(),
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      AppLogger.e('Error al guardar el QR', tag: 'VirtualCard', error: e);
      SacSnackBar.showMessenger(
        messenger,
        'virtual_card.qr_screen.save_error'.tr(),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sec = Sec.of(widget.vm.seccion);
    final subtitle = widget.vm.identitySubtitle(
      currentClassLabel: 'virtual_card.current_class_label'.tr(),
      sectionDisplayName: sec.label,
    );
    final size = (MediaQuery.sizeOf(context).shortestSide * 0.68)
        .clamp(200.0, 320.0)
        .toDouble();

    return SecureScreen(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          // The QR is read best on white, in light and dark mode.
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, top: 4),
                    child: SacPressable(
                      listenOnly: true,
                      child: IconButton(
                        enableFeedback: false,
                        tooltip: 'virtual_card.qr_screen.close'.tr(),
                        icon: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 24,
                          color: CredencialTokens.overlayIcon,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Image.asset(
                          sec.logo,
                          width: 44,
                          height: 44,
                          cacheWidth: 132,
                          excludeFromSemantics: true,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.vm.nombre,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: SacFontSize.headlineMedium,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: CredencialTokens.overlayIcon,
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: SacFontSize.bodyMedium,
                              color: CredencialTokens.mutedOnWhite,
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        Hero(
                          tag: widget.heroTag,
                          transitionOnUserGestures: true,
                          child: RepaintBoundary(
                            key: _qrBoundaryKey,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusLG),
                                border: Border.all(
                                  color: CredencialTokens.qrBorderOnWhite,
                                ),
                              ),
                              child: QrImageView(
                                data: widget.vm.qrData,
                                size: size,
                                padding: EdgeInsets.zero,
                                semanticsLabel: 'virtual_card.qr_alt'.tr(),
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
                        const SizedBox(height: 18),
                        const _LivePill(),
                        const SizedBox(height: 12),
                        Text(
                          'virtual_card.qr_screen.brightness_note'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: SacFontSize.bodySmall,
                            color: CredencialTokens.mutedOnWhite,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.vm.folio,
                          style: const TextStyle(
                            fontSize: SacFontSize.labelSmall,
                            fontFamily: 'monospace',
                            color: CredencialTokens.mutedOnWhite,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: SacButton.outline(
                    key: const Key('virtual-card-qr-save'),
                    text: _saving
                        ? 'virtual_card.qr_screen.saving'.tr()
                        : 'virtual_card.qr_screen.save'.tr(),
                    icon: HugeIcons.strokeRoundedDownload01,
                    isLoading: _saving,
                    onPressed: _saving ? null : _saveQrToGallery,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Valid · 09:01:22": the live clock and a pulsing dot.
class _LivePill extends StatelessWidget {
  const _LivePill();

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: SacFontSize.bodyMedium,
      fontWeight: FontWeight.w600,
      color: CredencialTokens.liveOnWhite,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: CredencialTokens.liveContainer,
        borderRadius: BorderRadius.circular(CredencialTokens.rChip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VerifiedDot(color: CredencialTokens.liveOnWhite, size: 7),
          const SizedBox(width: 7),
          Text('${'virtual_card.qr_screen.live'.tr()} · ', style: style),
          LiveClock(style: style),
        ],
      ),
    );
  }
}
