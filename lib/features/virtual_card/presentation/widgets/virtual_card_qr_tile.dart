import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class VirtualCardQrTile extends StatelessWidget {
  const VirtualCardQrTile({
    super.key,
    required this.data,
    this.maxSize = 160,
    this.padding = 12,
    this.borderRadius = 20,
    this.showShadow = false,
  });

  final String data;
  final double maxSize;
  final double padding;
  final double borderRadius;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : maxSize;
        final availableHeight =
            constraints.hasBoundedHeight ? constraints.maxHeight : maxSize;
        final size = math.max(
          0.0,
          math.min(maxSize, math.min(availableWidth, availableHeight)),
        );

        return RepaintBoundary(
          child: SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(color: const Color(0xFFE5E8EE)),
                boxShadow: showShadow
                    ? const [
                        BoxShadow(
                          blurRadius: 28,
                          offset: Offset(0, 12),
                          color: Color(0x220F1B2D),
                        ),
                      ]
                    : null,
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Semantics(
                  image: true,
                  label: 'virtual_card.qr_alt'.tr(),
                  child: QrImageView(
                    key: ValueKey(data),
                    data: data,
                    version: QrVersions.auto,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
