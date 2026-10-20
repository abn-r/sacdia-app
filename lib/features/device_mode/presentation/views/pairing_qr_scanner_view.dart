import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/widgets/sac_pressable.dart';
import '../../../../core/widgets/sac_top_bar.dart';
import '../../../qr/presentation/views/qr_scanner_view.dart'
    show QrCameraErrorView;

/// Cámara que lee el QR de vinculación del teléfono del tutor.
///
/// Devuelve (con `Navigator.pop`) el texto crudo del primer QR leído; quien la
/// abre decide si es un enlace de vinculación. NO envía nada a la API ni
/// registra el valor leído: es un secreto de un solo uso.
class PairingQrScannerView extends StatefulWidget {
  const PairingQrScannerView({super.key});

  @override
  State<PairingQrScannerView> createState() => _PairingQrScannerViewState();
}

class _PairingQrScannerViewState extends State<PairingQrScannerView> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  bool _done = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        _done = true;
        Navigator.of(context).pop(raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SacTopBar(
        title: 'device.pair.scanner_title'.tr(),
        actions: [
          SacPressable(
            listenOnly: true,
            child: IconButton(
              enableFeedback: false,
              tooltip: 'qr.torch_tooltip'.tr(),
              onPressed: () => _controller.toggleTorch(),
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedFlash,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => QrCameraErrorView(
              errorCode: error.errorCode,
              onRetry: () => _controller.start(),
            ),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.error != null) return const SizedBox.shrink();
              return Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth * 0.7;
                      return Center(
                        child: Container(
                          width: side,
                          height: side,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 32,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'device.pair.scanner_hint'.tr(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
