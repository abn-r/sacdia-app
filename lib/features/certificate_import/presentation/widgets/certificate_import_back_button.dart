import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_pressable.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_colors.dart';

class CertificateImportBackButton extends StatelessWidget {
  const CertificateImportBackButton({
    super.key,
    required this.fallbackLocation,
  });

  final String fallbackLocation;

  @override
  Widget build(BuildContext context) {
    final c = context.sac;

    return SacPressable(
      listenOnly: true,
      child: IconButton(
        enableFeedback: false,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: HugeIcon(
          icon: HugeIcons.strokeRoundedArrowLeft01,
          color: c.text,
          size: 22,
        ),
        onPressed: () {
          final navigator = Navigator.of(context);
          if (navigator.canPop()) {
            navigator.pop();
            return;
          }

          context.go(fallbackLocation);
        },
      ),
    );
  }
}
