import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'medico_tokens.dart';

/// Tarjeta hero con tipo de sangre + barra de completitud.
///
/// Muestra el tipo de sangre en grande — dato más buscado en emergencia.
/// Si está vacío muestra `—` y la barra actúa como invitación a completar.
///
/// Props:
/// - [bloodType]: string como "O+", "AB-"; null cuando no está registrado.
/// - [filled]: número de secciones completadas (0-5).
/// - [total]: total de secciones (normalmente 5).
/// - [onEditar]: callback al tocar la tarjeta (abre el selector de sangre).
class BloodHeroCard extends StatelessWidget {
  final String? bloodType;
  final int filled;
  final int total;
  final VoidCallback? onEditar;

  const BloodHeroCard({
    super.key,
    required this.filled,
    required this.total,
    this.bloodType,
    this.onEditar,
  });

  /// Parsea el Rh del tipo de sangre: "+" → positivo, "-" → negativo.
  String? _rhLabel() {
    final blood = bloodType;
    if (blood == null || blood.isEmpty || blood == '—') return null;
    final isPositive = blood.endsWith('+');
    return isPositive
        ? 'profile.medical_info.hero.rh_positive'.tr()
        : 'profile.medical_info.hero.rh_negative'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;
    final rhLabel = _rhLabel();

    return ClipRRect(
      borderRadius: BorderRadius.circular(MedicoTokens.rHero),
      child: GestureDetector(
        onTap: onEditar,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MedicoTokens.coral500, MedicoTokens.coral600],
            ),
            boxShadow: MedicoTokens.shadowHero,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Blob decorativo
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: const BoxDecoration(
                    color: Color(0x14FFFFFF), // 8% white
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _identidad(rhLabel)),
                      _gota(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _progreso(pct),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identidad(String? rhLabel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'profile.medical_info.hero.eyebrow'.tr(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.54, // ~0.14em
            fontWeight: FontWeight.w700,
            color: Color(0xD9FFFFFF),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              bloodType ?? 'profile.medical_info.hero.empty_blood'.tr(),
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
                letterSpacing: -1.3,
              ),
            ),
            if (rhLabel != null) ...[
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  rhLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xD9FFFFFF),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _gota() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0x2EFFFFFF), // 18% white
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.water_drop_outlined,
        color: Colors.white,
        size: 28,
      ),
    );
  }

  Widget _progreso(double pct) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'profile.medical_info.hero.completeness_title'.tr(),
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xD9FFFFFF),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'profile.medical_info.hero.completeness_format'.tr(
                namedArgs: {
                  'filled': filled.toString(),
                  'total': total.toString(),
                },
              ),
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: Stack(
            children: [
              Container(height: 6, color: const Color(0x38FFFFFF)),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x99FFFFFF), // 60% white
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
