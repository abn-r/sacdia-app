import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../widgets/medico/medico_tokens.dart';

/// Pantalla placeholder del Modo Emergencia (SOS).
///
/// PR4 reemplazará este contenido con la implementación completa
/// (WakeLock, orientación bloqueada, datos críticos en pantalla).
class EmergencyModeView extends StatelessWidget {
  const EmergencyModeView({super.key});

  static const routeName = '/profile/medical/sos';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MedicoTokens.rose50,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'profile.medical_info.sos.button'.tr(),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: MedicoTokens.rose500,
                letterSpacing: -1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'profile.medical_info.sos.coming_soon'.tr(),
              style: const TextStyle(
                fontSize: 16,
                color: MedicoTokens.ink600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
