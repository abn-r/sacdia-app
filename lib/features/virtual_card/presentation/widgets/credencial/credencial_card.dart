import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:sacdia_app/core/widgets/sac_profile_image.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../../core/utils/blood_type.dart';
import 'chip.dart';
import 'credencial_tokens.dart';
import 'credencial_view_model.dart';
import 'live_clock.dart';
import 'verified_dot.dart';

/// Tarjeta inmersiva — Variante B.
///
/// Gradiente diagonal + logo decorativo + foto/avatar + zona blanca con QR.
/// Recibe un [CredencialViewModel] construido desde [VirtualCard].
///
/// El QR embebido navega a [CredencialQrFullscreen] vía [onQrTap].
/// Pasar null en [onQrTap] deshabilita el tap (QR no disponible).
class CredencialCard extends StatelessWidget {
  final CredencialViewModel vm;
  final double qrSize; // 110 sm · 145 md · 175 lg
  final VoidCallback? onQrTap;

  const CredencialCard({
    super.key,
    required this.vm,
    this.qrSize = 145,
    this.onQrTap,
  });

  @override
  Widget build(BuildContext context) {
    final sec = Sec.of(vm.seccion);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(CredencialTokens.rImmersive),
        gradient: LinearGradient(
          begin: const Alignment(-0.5, -1),
          end: const Alignment(0.5, 1),
          colors: [sec.primary, sec.primaryDark],
          stops: const [0.0, 0.75],
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 36,
            offset: const Offset(0, 18),
            color: sec.primary.withAlpha(0x2B), // 17% per SPEC
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(CredencialTokens.rImmersive),
        child: Stack(
          children: [
            // Logo gigante decorativo
            Positioned(
              right: -60,
              top: -40,
              child: Opacity(
                opacity: 0.10,
                child: Transform.rotate(
                  angle: -0.21, // ~-12°
                  child: Image.asset(
                    sec.logo,
                    width: 280,
                    height: 280,
                    cacheWidth: 840,
                    cacheHeight: 840,
                  ),
                ),
              ),
            ),
            // Sheen overlay diagonal
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: const Alignment(-1, -0.5),
                      end: const Alignment(1, 0.5),
                      colors: [
                        Colors.transparent,
                        Colors.white.withAlpha(0x2E), // ~18%
                        Colors.transparent,
                      ],
                      stops: const [0.35, 0.5, 0.65],
                    ),
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _topRow(sec),
                _identidad(sec),
                _zonaBlanca(context, sec),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _shown(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '—' : trimmed;
  }

  Widget _stat(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            height: 1.1,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _shown(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.15,
            color: color ?? CredencialTokens.textPrimaryLight,
          ),
        ),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              _shown(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.15,
                color: CredencialTokens.textPrimaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topRow(Sec sec) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          Image.asset(
            sec.logo,
            width: 36,
            height: 36,
            cacheWidth: 108,
            cacheHeight: 108,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  sec.name.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '"${sec.motto}"',
                  style: TextStyle(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withAlpha(0xBF), // ~75%
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(0x2E), // ~18%
              borderRadius: BorderRadius.circular(CredencialTokens.rChip),
              border: Border.all(
                color: Colors.white.withAlpha(0x40), // ~25%
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const VerifiedDot(size: 6),
                const SizedBox(width: 6),
                Text(
                  vm.estado == 'Activo' ? 'VIGENTE' : 'SUSPENDIDO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: vm.estado == 'Activo'
                        ? Colors.white
                        : CredencialTokens.dangerSoft,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _identidad(Sec sec) {
    final hasPhoto = vm.fotoUrl != null && vm.fotoUrl!.isNotEmpty;
    final chipLabels = vm.identityChipLabels(
      currentClassLabel: 'virtual_card.current_class_label'.tr(),
      sectionDisplayName: sec.name,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(0x1F), // ~12%
              boxShadow: [
                BoxShadow(
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                  color: Colors.black.withAlpha(0x40), // ~25%
                ),
              ],
              border: Border.all(
                color: Colors.white.withAlpha(0x4D), // ~30%
              ),
            ),
            child: ClipOval(
              child: hasPhoto
                  ? SacProfileImage(
                      imageUrl: vm.fotoUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                      errorWidget: (_, __, ___) => _avatarFallback(sec),
                    )
                  : _avatarFallback(sec),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  vm.nombre,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chipLabels
                      .map((label) => CredChip(label: label))
                      .toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(Sec sec) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sec.accent, sec.primary],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        vm.iniciales,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: sec.primaryDark,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  Widget _zonaBlanca(BuildContext context, Sec sec) {
    final displayBloodType = BloodType.localizedDisplayFor(
      vm.tipoSangre,
      languageCode: context.locale.languageCode,
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFF), // .97 alpha
        border: Border(top: BorderSide(color: sec.accent, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _stat('Año', vm.anioEclesiastico),
                      ),
                      const _StatDivider(),
                      Expanded(
                        child: _stat(
                          'Estado',
                          vm.estado,
                          color: vm.estado == 'Activo'
                              ? CredencialTokens.success
                              : CredencialTokens.danger,
                        ),
                      ),
                      if (displayBloodType != null &&
                          displayBloodType.isNotEmpty) ...[
                        const _StatDivider(),
                        Expanded(
                          child: _stat(
                            'Sangre',
                            displayBloodType,
                            color: CredencialTokens.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFE4E7EC)),
                _line('Club', vm.club),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFE4E7EC)),
                _line('Campo', vm.campoLocal),
                const Divider(
                    height: 1, thickness: 1, color: Color(0xFFE4E7EC)),
                _line('Unión', vm.unionNombre),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: GestureDetector(
              onTap: onQrTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(CredencialTokens.rCard),
                  border: Border.all(color: CredencialTokens.borderLight),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                      color: Colors.black.withAlpha(0x0F),
                    ),
                  ],
                ),
                child: vm.qrData.isNotEmpty
                    ? QrImageView(
                        data: vm.qrData,
                        size: qrSize,
                        backgroundColor: Colors.white,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: sec.primaryDark,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: sec.primaryDark,
                        ),
                      )
                    : SizedBox(
                        width: qrSize,
                        height: qrSize,
                        child: const Center(
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedQrCode01,
                            size: 48,
                            color: Color(0xFF9AA0AB),
                          ),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0xFFE8EAEF), width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6B7280),
                        height: 1.35,
                      ),
                      children: [
                        TextSpan(
                          text: 'Iglesia Adventista del Séptimo Día\n',
                        ),
                        TextSpan(
                          text: 'Ministerio Juvenil',
                          style: TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'sacdia.com',
                      style: TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    Text(
                      'v.${vm.idCorto}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontFamily: 'monospace',
                        color: Color(0xFF9AA0AB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    vm.folio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF9AA0AB),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiveClock(
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF9AA0AB),
                    ),
                  ),
                  Text(
                    ' MX',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontFamily: 'monospace',
                      color: Color(0xFF9AA0AB),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      height: 28,
      child: DecoratedBox(
        decoration: BoxDecoration(color: Color(0xFFE4E7EC)),
      ),
    );
  }
}
