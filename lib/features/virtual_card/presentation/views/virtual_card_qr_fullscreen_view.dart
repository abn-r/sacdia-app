import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../domain/entities/virtual_card.dart';

class VirtualCardQrFullscreenView extends StatefulWidget {
  const VirtualCardQrFullscreenView({
    super.key,
    required this.card,
  });

  final VirtualCard card;

  @override
  State<VirtualCardQrFullscreenView> createState() =>
      _VirtualCardQrFullscreenViewState();
}

class _VirtualCardQrFullscreenViewState
    extends State<VirtualCardQrFullscreenView> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final qrToken = card.qrToken;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Hero(
                      tag: 'virtual-card-qr-${card.userId}',
                      child: _QrTile(card: card),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      card.fullName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                    ),
                    const SizedBox(height: 6),
                    if ((card.roleLabel ?? '').trim().isNotEmpty)
                      Text(
                        card.roleLabel!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.black87,
                            ),
                      ),
                    const SizedBox(height: 20),
                    if (qrToken == null || qrToken.isEmpty)
                      Text(
                        'virtual_card.expired_note'.tr(),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black12,
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    color: Colors.black,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QrTile extends StatelessWidget {
  const _QrTile({required this.card});

  final VirtualCard card;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.sizeOf(context).width * 0.8,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                blurRadius: 28,
                spreadRadius: 0,
                offset: Offset(0, 12),
                color: Color(0x220F1B2D),
              ),
            ],
          ),
          child: card.canShowQr
              ? QrImageView(
                  data: card.qrToken!,
                  version: QrVersions.auto,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                )
              : Center(
                  child: Text(
                    'virtual_card.qr_unavailable'.tr(),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
      ),
    );
  }
}
