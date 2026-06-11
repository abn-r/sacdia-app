import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import 'credencial_tokens.dart';
import 'package:sacdia_app/core/utils/icon_helper.dart';

enum ActionIcon { wallet, share, pdf }

class ActionPill extends StatelessWidget {
  final String label;
  final ActionIcon icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool dark;

  const ActionPill({
    super.key,
    required this.label,
    required this.icon,
    this.onTap,
    this.primary = false,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? const Color(0xFF0F1115)
        : dark
            ? Colors.white.withAlpha(0x0F) // ~6%
            : Colors.white;
    final fg = primary
        ? Colors.white
        : dark
            ? CredencialTokens.textPrimaryDark
            : CredencialTokens.textPrimaryLight;
    final border = primary
        ? Colors.transparent
        : dark
            ? Colors.white.withAlpha(0x14) // ~8%
            : CredencialTokens.borderLight;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(CredencialTokens.rPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CredencialTokens.rPill),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CredencialTokens.rPill),
            border: Border.all(color: border),
            boxShadow: primary
                ? [
                    BoxShadow(
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                      color: const Color(0xFF0F1115).withAlpha(0x55), // ~33%
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(icon: _iconFor(icon), size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  HugeIconData _iconFor(ActionIcon i) {
    switch (i) {
      case ActionIcon.wallet:
        return HugeIcons.strokeRoundedWallet01;
      case ActionIcon.share:
        return HugeIcons.strokeRoundedShare08;
      case ActionIcon.pdf:
        return HugeIcons.strokeRoundedPdf01;
    }
  }
}
