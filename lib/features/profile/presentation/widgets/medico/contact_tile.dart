import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/features/post_registration/data/models/emergency_contact_model.dart';
import 'medico_tokens.dart';

/// Fila de contacto de emergencia con avatar de inicial y botones
/// rápidos de llamar / SMS.
///
/// Los callbacks [onCall] y [onSms] reciben el teléfono limpio (solo
/// dígitos y "+") para que el padre llame a `launchUrl(Uri.parse('tel:...'))`.
class ContactTile extends StatelessWidget {
  final EmergencyContactModel contact;
  final ValueChanged<String>? onCall;
  final ValueChanged<String>? onSms;

  const ContactTile({
    super.key,
    required this.contact,
    this.onCall,
    this.onSms,
  });

  static String _cleanPhone(String p) => p.replaceAll(RegExp(r'[^0-9+]'), '');

  String get _initial =>
      contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?';

  String get _cleanedPhone => _cleanPhone(contact.phone);

  @override
  Widget build(BuildContext context) {
    final relation = contact.relationshipTypeName ?? '—';
    final meta = '$relation · ${contact.phone}';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: MedicoTokens.ink50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _avatar(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: MedicoTokens.ink900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: MedicoTokens.ink500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _quickButton(
            icon: HugeIcons.strokeRoundedCall,
            bg: MedicoTokens.mint50,
            fg: MedicoTokens.mint500,
            onTap: () => onCall?.call(_cleanedPhone),
          ),
          const SizedBox(width: 6),
          _quickButton(
            icon: HugeIcons.strokeRoundedMessage01,
            bg: MedicoTokens.ink100,
            fg: MedicoTokens.ink600,
            onTap: () => onSms?.call(_cleanedPhone),
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: MedicoTokens.coral100,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        _initial,
        style: const TextStyle(
          color: MedicoTokens.coral600,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _quickButton({
    required List<List<dynamic>> icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(MedicoTokens.rField),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MedicoTokens.rField),
        child: SizedBox(
          width: 36,
          height: 36,
          child: HugeIcon(icon: icon, color: fg, size: 16),
        ),
      ),
    );
  }
}
