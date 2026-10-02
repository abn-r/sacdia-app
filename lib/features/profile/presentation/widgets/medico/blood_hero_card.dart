import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:sacdia_app/core/theme/sac_accent.dart';
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
    final accent = SacAccent.of(context).forBrightness(
      Theme.brightnessOf(context),
    );
    final ink = accent.onColor;

    return ClipRRect(
      borderRadius: BorderRadius.circular(MedicoTokens.rHero),
      child: GestureDetector(
        onTap: onEditar,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [accent.color, accent.dark],
            ),
            boxShadow: [
              BoxShadow(
                color: accent.color.withValues(alpha: 0.4),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -10,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: ink.withValues(alpha: 0.08),
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
                      Expanded(child: _identidad(rhLabel, ink)),
                      _gota(ink),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _progreso(pct, ink),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _identidad(String? rhLabel, Color ink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'profile.medical_info.hero.eyebrow'.tr(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.54, // ~0.14em
            fontWeight: FontWeight.w700,
            color: ink.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(
                  bloodType ?? 'profile.medical_info.hero.empty_blood'.tr(),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: ink,
                    height: 1,
                    letterSpacing: -1.3,
                  ),
                ),
              ),
            ),
            if (rhLabel != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    rhLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: ink.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _gota(Color ink) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
      ),
      child: HugeIcon(
        icon: HugeIcons.strokeRoundedBlood,
        color: ink,
        size: 28,
      ),
    );
  }

  Widget _progreso(double pct, Color ink) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'profile.medical_info.hero.completeness_title'.tr(),
              style: TextStyle(
                fontSize: 12,
                color: ink.withValues(alpha: 0.85),
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
              style: TextStyle(
                fontSize: 12,
                color: ink,
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
              Container(height: 6, color: ink.withValues(alpha: 0.22)),
              FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: ink,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: ink.withValues(alpha: 0.6),
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
