import 'package:flutter/material.dart';

import 'credencial_tokens.dart';

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
              Icon(_iconFor(icon), size: 16, color: fg),
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

  IconData _iconFor(ActionIcon i) {
    switch (i) {
      case ActionIcon.wallet:
        return Icons.account_balance_wallet_outlined;
      case ActionIcon.share:
        return Icons.ios_share_rounded;
      case ActionIcon.pdf:
        return Icons.picture_as_pdf_outlined;
    }
  }
}
